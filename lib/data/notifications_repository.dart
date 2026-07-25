import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/app_notification.dart';

/// Society notifications (e.g. a resident paid a bill). A [ChangeNotifier] so a
/// bell badge can update live.
class NotificationsRepository extends ChangeNotifier {
  NotificationsRepository._();
  static final NotificationsRepository instance = NotificationsRepository._();

  final _api = ApiClient.instance;
  List<AppNotification> _items = [];
  int _unread = 0;

  List<AppNotification> get all => List.unmodifiable(_items);
  int get unread => _unread;

  Future<void> load() async {
    final data = await _api.get('/notifications') as Map<String, dynamic>;
    _items = (data['notifications'] as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    _unread = (data['unread'] as num?)?.toInt() ?? 0;
    notifyListeners();
  }

  /// Marks everything read (call when the notifications screen opens).
  Future<void> markAllRead() async {
    if (_unread == 0) return;
    await _api.patch('/notifications/read');
    _unread = 0;
    notifyListeners();
  }
}
