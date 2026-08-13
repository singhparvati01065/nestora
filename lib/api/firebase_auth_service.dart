import 'package:firebase_auth/firebase_auth.dart';
import '../push_notifications.dart';

import '../models/user_role.dart';
import 'api_client.dart';
import 'auth_api.dart';
import 'session.dart';

/// Default country code applied to numbers typed without one.
const _defaultCountryCode = '+91';

/// Turns a typed number into E.164, which is the only format Firebase accepts.
/// A number already carrying a `+` is passed through untouched.
String toE164(String phone) {
  final digits = phone.replaceAll(RegExp(r'[\s-]'), '');
  if (digits.startsWith('+')) return digits;
  return '$_defaultCountryCode$digits';
}

/// Phone/OTP auth against Firebase, exchanged for a Nestora JWT.
///
/// Firebase proves the number; the backend owns the identity. Signing in is two
/// steps: verify the OTP with Firebase, then hand the resulting ID token to
/// `POST /auth/firebase`, which returns the app's real user (role and all) and
/// the JWT every other repository sends as its Bearer token.
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  final _auth = FirebaseAuth.instance;

  /// Sends an OTP to [phone].
  ///
  /// [onCodeSent] gives back the verificationId needed by [verifyOtp].
  /// [onAutoVerified] fires only on Android when the SMS is auto-read; the
  /// credential is already signed in at that point, so the caller should skip
  /// the OTP screen rather than ask for a code.
  Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String message) onFailed,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: toE164(phone),
      forceResendingToken: resendToken,
      verificationCompleted: onAutoVerified ?? (_) {},
      verificationFailed: (e) => onFailed(messageFor(e)),
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  /// Signs in with the SMS [smsCode] and stores the session.
  ///
  /// [name] and [role] are only used when this is a signup — and even then the
  /// backend ignores them if the number already has an account.
  Future<AuthUser> verifyOtp({
    required String verificationId,
    required String smsCode,
    String? name,
    UserRole? role,
    List<String>? trades,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return signInWith(credential, name: name, role: role, trades: trades);
  }

  /// Completes sign-in for a credential and stores the session. Shared by the
  /// manual OTP path and Android's auto-verification.
  Future<AuthUser> signInWith(
    PhoneAuthCredential credential, {
    String? name,
    UserRole? role,
    List<String>? trades,
  }) async {
    final result = await _auth.signInWithCredential(credential);
    final idToken = await result.user!.getIdToken();
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'no-id-token',
        message: 'Could not read your Firebase session.',
      );
    }
    // AuthApi stores the backend's JWT + user in Session.
    return AuthApi.instance.firebaseLogin(
      idToken: idToken,
      name: name,
      role: role,
      trades: trades,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
    // Before the session goes: unregistering needs the token it carries.
    await PushNotifications.instance.unregister();
    await Session.instance.clear();
  }

  /// A user-facing message for a sign-in failure.
  ///
  /// Sign-in spans two systems, so this handles both: Firebase's own errors and
  /// anything the backend token exchange throws.
  static String messageFor(Object error) {
    if (error is! FirebaseAuthException) return ApiClient.messageFor(error);
    switch (error.code) {
      case 'invalid-phone-number':
        return 'That mobile number looks invalid.';
      case 'invalid-verification-code':
        return 'Wrong code. Check the SMS and try again.';
      case 'session-expired':
        return 'The code expired. Request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'quota-exceeded':
        return 'SMS limit reached. Try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return error.message ?? 'Could not verify your number.';
    }
  }
}
