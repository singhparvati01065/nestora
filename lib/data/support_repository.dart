import '../api/api_client.dart';
import '../models/support_ticket.dart';

/// The society admin's support tickets, backed by the API.
class SupportRepository {
  SupportRepository._();
  static final SupportRepository instance = SupportRepository._();

  final _api = ApiClient.instance;
  List<SupportTicket> _tickets = [];

  List<SupportTicket> get all => List.unmodifiable(_tickets);

  Future<void> load() async {
    final data = await _api.get('/support') as List;
    _tickets = data
        .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> create({
    required String category,
    required String subject,
    required String message,
  }) async {
    await _api.post('/support', body: {
      'category': category,
      'subject': subject,
      'message': message,
    });
    await load();
  }
}
