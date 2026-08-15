import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'api/auth_api.dart';
import 'api/session.dart';
import 'feature_flags.dart';
import 'firebase_options.dart';
import 'models/user_role.dart';
import 'screens/home_for_role.dart';
import 'screens/role_selection_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Restore the saved profile before any screen reads Session.user.
  await Session.instance.restore();
  final role = await _resumeSession();
  // Screens read the flags synchronously, so they must be in before the first
  // build. The call never throws and falls back to "everything on".
  await FeatureFlags.instance.load();
  runApp(NestoraApp(signedInAs: role));
}

/// Decides whether the saved session still gets someone straight into the app.
///
/// The stored token is checked against the server so that an account that was
/// removed, banned, or had its society suspended cannot keep walking back in
/// on an old token. A network failure is not that case: the session is kept and
/// the screens themselves surface the error, otherwise every commute through a
/// tunnel would log everyone out.
Future<UserRole?> _resumeSession() async {
  if (!Session.instance.isLoggedIn) return null;
  try {
    // refresh() re-registers this device for push on the way through, so a
    // returning user keeps receiving notifications without signing in again.
    final user = await AuthApi.instance.refresh();
    return user.role;
  } on DioException catch (e) {
    final code = e.response?.statusCode ?? 0;
    if (code == 401 || code == 403) {
      await Session.instance.clear();
      return null;
    }
    return Session.instance.user?.role;
  } catch (_) {
    return Session.instance.user?.role;
  }
}

class NestoraApp extends StatelessWidget {
  const NestoraApp({super.key, this.signedInAs});

  /// Set when a saved session was resumed: the app opens on that role's home
  /// instead of asking again who the person is.
  final UserRole? signedInAs;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nestora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: signedInAs == null
          ? const RoleSelectionScreen()
          : homeForRole(signedInAs!),
    );
  }
}
