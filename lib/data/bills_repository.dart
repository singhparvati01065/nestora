import '../api/api_client.dart';
import '../models/maintenance_bill.dart';

/// Maintenance bills, backed by the API. [load] can be scoped to a flat (a
/// resident) or unscoped (admin).
class BillsRepository {
  BillsRepository._();
  static final BillsRepository instance = BillsRepository._();

  final _api = ApiClient.instance;
  List<MaintenanceBill> _bills = [];
  double _collected = 0;
  double _pending = 0;
  int _paidCount = 0;
  int _pendingCount = 0;

  List<MaintenanceBill> get all => List.unmodifiable(_bills);
  double get totalCollected => _collected;
  double get totalPending => _pending;
  int get paidCount => _paidCount;
  int get pendingCount => _pendingCount;

  List<MaintenanceBill> forFlat(String flatNumber) =>
      _bills.where((b) => b.flatNumber == flatNumber).toList();

  double pendingForFlat(String flatNumber) => _bills
      .where((b) => b.flatNumber == flatNumber && !b.paid)
      .fold(0, (sum, b) => sum + b.amount);

  Future<void> load({String? flatId}) async {
    final data = await _api.get(
      '/bills',
      query: flatId != null ? {'flatId': flatId} : null,
    ) as Map<String, dynamic>;
    _bills = (data['bills'] as List)
        .map((e) => MaintenanceBill.fromJson(e as Map<String, dynamic>))
        .toList();
    final s = data['summary'] as Map<String, dynamic>;
    _collected = (s['collected'] as num).toDouble();
    _pending = (s['pending'] as num).toDouble();
    _paidCount = (s['paidCount'] as num).toInt();
    _pendingCount = (s['pendingCount'] as num).toInt();
  }

  /// Generates one bill of [kind] ('RENT' | 'MANUAL' | 'OTHER') for a flat,
  /// starting from [startDate]. RENT/MANUAL recur monthly; OTHER is a one-off
  /// named ([title]) charge. Returns how many bills that created.
  Future<int> generate({
    required DateTime startDate,
    required String flatId,
    required String kind,
    required double amount,
    String? title,
  }) async {
    final data = await _api.post('/bills/generate', body: {
      'startDate': startDate.toIso8601String().split('T').first,
      'flatId': flatId,
      'kind': kind,
      'amount': amount,
      'title': ?title,
    });
    await load();
    return (data['created'] as num?)?.toInt() ?? 0;
  }

  /// Edits a single bill's [amount], due [date] and — for an OTHER charge —
  /// its [title]. Only that bill changes; recurring amounts stay put.
  Future<void> update(
    MaintenanceBill bill, {
    double? amount,
    DateTime? date,
    String? title,
  }) async {
    await _api.patch('/bills/${bill.id}', body: {
      'amount': ?amount,
      'startDate': ?date?.toIso8601String().split('T').first,
      'title': ?title,
    });
    await load();
  }

  Future<void> setPaid(MaintenanceBill bill, bool paid) async {
    await _api.patch('/bills/${bill.id}/${paid ? 'pay' : 'unpay'}');
    await load();
  }

  Future<void> delete(MaintenanceBill bill) async {
    await _api.delete('/bills/${bill.id}');
    await load();
  }

  /// Pays several bills as one payment (rent + maintenance together). The
  /// backend stamps them all with the same time so history shows one entry.
  Future<void> payMany(Iterable<MaintenanceBill> bills) async {
    final ids = bills.map((b) => b.id).toList();
    if (ids.isEmpty) return;
    await _api.post('/bills/pay', body: {'ids': ids});
    await load();
  }

  List<MaintenanceBill> unpaidForFlat(String flatNumber) => _bills
      .where((b) => b.flatNumber == flatNumber && !b.paid)
      .toList();

  List<MaintenanceBill> paidForFlat(String flatNumber) => _bills
      .where((b) => b.flatNumber == flatNumber && b.paid)
      .toList();
}
