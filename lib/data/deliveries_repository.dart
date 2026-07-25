import '../api/api_client.dart';
import '../models/delivery.dart';

/// Parcels/deliveries held at the gate, backed by the API.
class DeliveriesRepository {
  DeliveriesRepository._();
  static final DeliveriesRepository instance = DeliveriesRepository._();

  final _api = ApiClient.instance;
  List<Delivery> _deliveries = [];

  List<Delivery> get all => List.unmodifiable(_deliveries);

  int get pendingCount => _deliveries.where((d) => !d.collected).length;

  Future<void> load() async {
    final data = await _api.get('/deliveries') as List;
    _deliveries =
        data.map((e) => Delivery.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> add({required String courier, required String flatId}) async {
    await _api.post('/deliveries', body: {'courier': courier, 'flatId': flatId});
    await load();
  }

  Future<void> toggleCollected(Delivery delivery) async {
    await _api.patch('/deliveries/${delivery.id}/collected');
    await load();
  }
}
