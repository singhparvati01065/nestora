import 'package:flutter/material.dart';

import '../api/session.dart';
import '../push_notifications.dart';
import 'role_selection_screen.dart';

/// Ends the session and puts the app back on the role picker.
///
/// The whole stack is replaced rather than popped. Since a saved session now
/// opens straight on the role's home, that home IS the first route — popping
/// back to it after signing out left the app sitting on a screen it no longer
/// had a session for, which read as "logout does nothing".
Future<void> signOutTo(BuildContext context) async {
  // Before the session goes: unregistering needs the token it carries.
  await PushNotifications.instance.unregister();
  await Session.instance.clear();
  if (!context.mounted) return;
  await Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    (route) => false,
  );
}

/// The same landing, for a screen that has already cleared the session itself.
Future<void> backToRolePicker(BuildContext context) async {
  if (!context.mounted) return;
  await Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    (route) => false,
  );
}
