import 'package:flutter/material.dart';
import 'sign_out.dart';


/// Shown in place of a whole role's home when the one module that role exists
/// for — the gate for a guard, complaints for maintenance staff — has been
/// switched off in the super-admin panel.
///
/// Carries its own log-out, because it replaces the shell that normally holds
/// the profile tab, and nobody should end up stuck on this screen.
class FeatureOffScreen extends StatelessWidget {
  const FeatureOffScreen({
    super.key,
    required this.title,
    required this.feature,
    required this.accent,
  });

  /// App bar title — usually the role, e.g. "Security · Main Gate".
  final String title;

  /// The module that is off, as the user would name it, e.g. "Visitor
  /// management".
  final String feature;

  final Color accent;

  Future<void> _logout(BuildContext context) => signOutTo(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pause_circle_outline, size: 56, color: accent),
              const SizedBox(height: 18),
              Text(
                '$feature is unavailable',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This module has been turned off for the platform. Please '
                'check back later or contact your society admin.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
