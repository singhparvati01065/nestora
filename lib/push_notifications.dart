import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api/api_client.dart';

/// Registers this install for push and keeps the backend's copy of its FCM
/// token current.
///
/// Called after sign-in (the token is stored against the logged-in user) and
/// dropped on sign-out, so a shared phone never delivers one person's
/// notifications to the next.
class PushNotifications {
  PushNotifications._();

  static final PushNotifications instance = PushNotifications._();

  final _messaging = FirebaseMessaging.instance;
  String? _token;

  /// Asks for permission, then hands the token to the backend. Never throws:
  /// push is a bonus, not a reason to fail a sign-in.
  Future<void> register() async {
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push permission denied.');
        return;
      }
      // iOS hands out an FCM token only once APNs has given it one.
      final token = await _messaging.getToken();
      if (token == null) return;
      await _send(token);

      // FCM rotates tokens on reinstall, restore and app updates.
      _messaging.onTokenRefresh.listen(_send);
    } catch (e) {
      debugPrint('Push registration skipped: $e');
    }
  }

  Future<void> _send(String token) async {
    _token = token;
    try {
      await ApiClient.instance.post(
        '/devices',
        body: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
      );
    } catch (e) {
      debugPrint('Could not register device token: $e');
    }
  }

  /// Drops this device's token on sign-out. Runs before the session is
  /// cleared, since the call needs the token that is about to go away.
  Future<void> unregister() async {
    final token = _token ?? await _messaging.getToken().catchError((_) => null);
    if (token == null) return;
    try {
      await ApiClient.instance.delete('/devices', body: {'token': token});
    } catch (e) {
      debugPrint('Could not unregister device token: $e');
    }
    _token = null;
  }
}
