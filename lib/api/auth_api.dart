import 'dart:async';

import '../models/user_role.dart';
import '../push_notifications.dart';
import 'api_client.dart';
import 'session.dart';

/// Backend role enum value for a [UserRole].
String roleToApi(UserRole role) {
  switch (role) {
    case UserRole.societyAdmin:
      return 'SOCIETY_ADMIN';
    case UserRole.securityGuard:
      return 'SECURITY_GUARD';
    case UserRole.resident:
      return 'RESIDENT';
    case UserRole.maintenanceStaff:
      return 'MAINTENANCE_STAFF';
  }
}

/// Auth calls against the backend. On success the token + user are stored in
/// [Session].
///
/// The app signs in with Firebase phone OTP, then calls [firebaseLogin] to
/// trade that for a Nestora JWT — every other repository needs the backend's
/// own token, and the role has to come from the database, not the client.
/// [login] and [register] are the older phone+password path, still live for the
/// seeded accounts.
class AuthApi {
  AuthApi._();
  static final AuthApi instance = AuthApi._();

  final _api = ApiClient.instance;

  Future<AuthUser> login({
    required String phone,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/login',
      body: {'phone': phone, 'password': password},
    );
    return _store(data);
  }

  Future<AuthUser> register({
    required String name,
    required String phone,
    required String password,
    required UserRole role,
    String? staffLabel,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'phone': phone,
      'password': password,
      'role': roleToApi(role),
    };
    if (staffLabel != null) body['staffLabel'] = staffLabel;
    final data = await _api.post('/auth/register', body: body);
    return _store(data);
  }

  /// Exchanges a verified Firebase ID token for a Nestora JWT.
  ///
  /// [name] and [role] only take effect if the backend has never seen this
  /// phone number; for a number that already exists the stored role wins.
  Future<AuthUser> firebaseLogin({
    required String idToken,
    String? name,
    UserRole? role,
    List<String>? trades,
  }) async {
    final body = <String, dynamic>{'idToken': idToken};
    if (name != null) body['name'] = name;
    if (role != null) body['role'] = roleToApi(role);
    if (trades != null) body['trades'] = trades;
    final data = await _api.post('/auth/firebase', body: body);
    return _store(data);
  }

  /// ⚠️ TEMPORARY — signs in with no verification at all. Guarded by
  /// [kBypassOtp]; see `lib/dev_flags.dart`. Delete with the bypass.
  Future<AuthUser> devLogin({
    required String phone,
    String? name,
    UserRole? role,
    List<String>? trades,
  }) async {
    final body = <String, dynamic>{'phone': phone};
    if (name != null) body['name'] = name;
    if (role != null) body['role'] = roleToApi(role);
    if (trades != null) body['trades'] = trades;
    final data = await _api.post('/auth/dev-login', body: body);
    return _store(data);
  }

  /// Re-fetches a fresh token + user from the backend and re-stores the session.
  /// Call after an action that changes a claim baked into the JWT (e.g. creating
  /// the first society sets `societyId`), so later requests aren't stale.
  Future<AuthUser> refresh() async {
    final data = await _api.post('/auth/refresh');
    return _store(data);
  }

  /// Marks an argument the caller did not pass, which is NOT the same as
  /// passing null — null means "clear this field".
  static const Object _unset = Object();

  /// Updates your own name/photo and refreshes the cached [Session] user.
  ///
  /// [photoUrl] takes a url to set it, an explicit `null` to remove the photo,
  /// or nothing at all to leave it alone. Collapsing those last two would make
  /// "Remove photo" silently do nothing.
  ///
  /// The backend returns the whole user, but not a new token — the existing
  /// one stays valid, so the JWT is reused as-is.
  Future<AuthUser> updateMe({
    String? name,
    Object? photoUrl = _unset,
    List<String>? trades,
  }) async {
    final body = <String, dynamic>{'name': ?name, 'trades': ?trades};
    if (!identical(photoUrl, _unset)) body['photoUrl'] = photoUrl;

    final data = await _api.patch('/users/me', body: body);
    final user = AuthUser.fromJson(data as Map<String, dynamic>);
    await Session.instance.save(Session.instance.token ?? '', user);
    return user;
  }

  Future<AuthUser> _store(dynamic data) async {
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await Session.instance.save(data['accessToken'] as String, user);
    // Every sign-in path lands here, so this is the one place the device has
    // to be registered for push. It needs the token saved above.
    unawaited(PushNotifications.instance.register());
    return user;
  }
}
