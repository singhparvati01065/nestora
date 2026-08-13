import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'api/session.dart';
import 'feature_flags.dart';
import 'firebase_options.dart';
import 'screens/role_selection_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Restore the saved profile before any screen reads Session.user.
  await Session.instance.restore();
  // Screens read the flags synchronously, so they must be in before the first
  // build. The call never throws and falls back to "everything on".
  await FeatureFlags.instance.load();
  runApp(const NestoraApp());
}

class NestoraApp extends StatelessWidget {
  const NestoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nestora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const RoleSelectionScreen(),
    );
  }
}
