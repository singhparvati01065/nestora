import '../api/api_client.dart';
import '../models/pre_approved_visitor.dart';

/// Resident-approved expected visitors, backed by the API. The guard sees the
/// whole society; a resident sees their own flat's list.
class PreApprovedRepository {
  PreApprovedRepository._();
  static final PreApprovedRepository instance = PreApprovedRepository._();

  final _api = ApiClient.instance;
  List<PreApprovedVisitor> _list = [];

  List<PreApprovedVisitor> get all => List.unmodifiable(_list);

  int get pendingCount => _list.where((p) => !p.checkedIn).length;

  List<PreApprovedVisitor> forFlat(String flatNumber) =>
      _list.where((p) => p.flatNumber == flatNumber).toList();

  Future<void> load() async {
    final data = await _api.get('/pre-approved') as List;
    _list = data
        .map((e) => PreApprovedVisitor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// A resident pre-approves a visitor for their own flat (the backend uses the
  /// caller's flat).
  Future<void> add({
    required String name,
    required String purpose,
    required String validLabel,
  }) async {
    await _api.post('/pre-approved',
        body: {'name': name, 'purpose': purpose, 'validLabel': validLabel});
    await load();
  }

  /// Guard checks a pre-approved visitor in (also creates a Visitor entry).
  Future<void> markCheckedIn(PreApprovedVisitor pre) async {
    await _api.patch('/pre-approved/${pre.id}/check-in');
    await load();
  }
}
