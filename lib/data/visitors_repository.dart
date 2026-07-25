import '../api/api_client.dart';
import '../models/visitor.dart';

/// Gate visitors, backed by the API.
class VisitorsRepository {
  VisitorsRepository._();
  static final VisitorsRepository instance = VisitorsRepository._();

  final _api = ApiClient.instance;
  List<Visitor> _visitors = [];
  int _insideCount = 0;
  int _todayCount = 0;

  List<Visitor> get all => List.unmodifiable(_visitors);
  int get insideCount => _insideCount;
  int get todayCount => _todayCount;

  Future<void> load() async {
    final data = await _api.get('/visitors') as Map<String, dynamic>;
    _visitors = (data['visitors'] as List)
        .map((e) => Visitor.fromJson(e as Map<String, dynamic>))
        .toList();
    final s = data['summary'] as Map<String, dynamic>;
    _insideCount = (s['insideNow'] as num).toInt();
    _todayCount = (s['today'] as num).toInt();
  }

  Future<void> add({
    required String name,
    required String phone,
    String? flatId,
    required String purpose,
    String? vehicleNo,
  }) async {
    final body = <String, dynamic>{'name': name, 'purpose': purpose};
    if (phone.isNotEmpty) body['phone'] = phone;
    if (flatId != null) body['flatId'] = flatId;
    if (vehicleNo != null) body['vehicleNo'] = vehicleNo;
    await _api.post('/visitors', body: body);
    await load();
  }

  Future<void> checkout(Visitor visitor) async {
    await _api.patch('/visitors/${visitor.id}/checkout');
    await load();
  }
}
