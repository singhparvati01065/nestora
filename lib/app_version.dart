import 'dart:io';

import 'package:flutter/material.dart';

import 'api/api_client.dart';

/// This build's version. Keep in sync with `pubspec.yaml`. The backend's
/// App Version config (set in the super-admin panel) is compared against this
/// to decide whether to prompt / force an update.
const String kAppVersion = '1.0.0';

/// Returns >0 if [a] is newer than [b], 0 if equal, <0 if older.
int _compareVersions(String a, String b) {
  final pa = a.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
  final pb = b.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

/// Fetches the platform's latest version from the API and, if this build is
/// older, shows an update dialog — blocking (non-dismissible) when the config
/// marks the update as forced.
Future<void> checkForUpdate(BuildContext context) async {
  Map<String, dynamic> data;
  try {
    data = await ApiClient.instance.get('/app-version') as Map<String, dynamic>;
  } catch (_) {
    return; // offline / server down — don't block the app
  }

  // Platform-wide maintenance takes priority over the update check.
  if ((data['maintenanceMode'] as bool?) ?? false) {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: AlertDialog(
          icon: Icon(Icons.build_circle_outlined),
          title: Text('Under maintenance'),
          content: Text(
              'Nestora is temporarily down for maintenance. Please try again '
              'in a little while.'),
        ),
      ),
    );
    return;
  }

  final latest = (Platform.isIOS
          ? data['iosVersion']
          : data['androidVersion']) as String? ??
      kAppVersion;
  if (_compareVersions(kAppVersion, latest) >= 0) return; // already current

  final force = (data['forceUpdate'] as bool?) ?? false;
  final notes = (data['releaseNotes'] as String?)?.trim() ?? '';
  if (!context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: !force,
    builder: (context) => PopScope(
      canPop: !force,
      child: AlertDialog(
        icon: Icon(force ? Icons.system_update : Icons.new_releases_outlined),
        title: Text(force ? 'Update required' : 'Update available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(force
                ? 'A newer version ($latest) is required to keep using Nestora.'
                : 'Nestora $latest is available.'),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text("What's new",
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(notes),
            ],
          ],
        ),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          FilledButton(
            // In production this opens the Play Store / App Store.
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Update'),
          ),
        ],
      ),
    ),
  );
}
