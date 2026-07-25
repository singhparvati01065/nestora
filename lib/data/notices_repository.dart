import '../api/api_client.dart';
import '../models/notice.dart';
import '../utils/time_format.dart';

/// Notices feed, backed by the API.
class NoticesRepository {
  NoticesRepository._();
  static final NoticesRepository instance = NoticesRepository._();

  final _api = ApiClient.instance;
  List<Notice> _notices = [];

  List<Notice> get all => List.unmodifiable(_notices);

  Future<void> load() async {
    final data = await _api.get('/notices') as List;
    _notices = data
        .map((e) => Notice.fromJson(
              e as Map<String, dynamic>,
              relativeLabelFromIso(e['createdAt'] as String?),
            ))
        .toList();
  }

  Future<void> add({
    required String title,
    required String body,
    bool pinned = false,
  }) async {
    await _api.post('/notices',
        body: {'title': title, 'body': body, 'pinned': pinned});
    await load();
  }

  Future<void> togglePinned(Notice notice) async {
    await _api.patch('/notices/${notice.id}/pin');
    await load();
  }

  Future<void> remove(Notice notice) async {
    await _api.delete('/notices/${notice.id}');
    await load();
  }
}
