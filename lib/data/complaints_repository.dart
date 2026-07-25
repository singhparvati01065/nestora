import '../api/api_client.dart';
import '../models/complaint.dart';
import '../utils/time_format.dart';

/// A society's real maintenance staff member, from `GET /complaints/staff` —
/// used by the admin's assign dropdown.
class StaffMember {
  StaffMember({required this.name, required this.trades});

  final String name;
  final List<String> trades;

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        name: json['name'] as String,
        trades: ((json['trades'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Complaints, backed by the API. [load] fetches the caller's visible set
/// (residents are auto-scoped to their flat by the backend); helpers filter the
/// cache client-side.
class ComplaintsRepository {
  ComplaintsRepository._();
  static final ComplaintsRepository instance = ComplaintsRepository._();

  final _api = ApiClient.instance;
  List<Complaint> _complaints = [];

  List<Complaint> get all => List.unmodifiable(_complaints);

  int countByStatus(ComplaintStatus status) =>
      _complaints.where((c) => c.status == status).length;

  List<Complaint> forFlat(String flatNumber) =>
      _complaints.where((c) => c.flatNumber == flatNumber).toList();

  int openCountForFlat(String flatNumber) => _complaints
      .where((c) => c.flatNumber == flatNumber && c.status != ComplaintStatus.resolved)
      .length;

  List<Complaint> assignedTo(String staff) =>
      _complaints.where((c) => c.assignedTo == staff).toList();

  List<Complaint> get unassigned =>
      _complaints.where((c) => c.assignedTo == null).toList();

  /// Unassigned complaints a staff with [trades] can pick up — those whose
  /// category is one of their trades. This is the trade-based routing.
  List<Complaint> availableFor(List<String> trades) => _complaints
      .where((c) => c.assignedTo == null && trades.contains(c.category))
      .toList();

  /// The society's real maintenance staff (name + trades), for the admin's
  /// assign dropdown.
  Future<List<StaffMember>> fetchStaff() async {
    final data = await _api.get('/complaints/staff') as List;
    return data
        .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> load() async {
    final data = await _api.get('/complaints') as List;
    _complaints = data
        .map((e) => Complaint.fromJson(
              e as Map<String, dynamic>,
              relativeLabelFromIso(e['createdAt'] as String?),
            ))
        .toList();
  }

  Future<void> add({
    required String title,
    required String description,
    required String flatId,
    required String category,
  }) async {
    await _api.post('/complaints', body: {
      'title': title,
      'description': description,
      'flatId': flatId,
      'category': category,
    });
    await load();
  }

  Future<void> updateStatus(Complaint complaint, ComplaintStatus status) async {
    await _api.patch('/complaints/${complaint.id}/status',
        body: {'status': status.api});
    await load();
  }

  Future<void> assign(Complaint complaint, String? staff) async {
    await _api
        .patch('/complaints/${complaint.id}/assign', body: {'assignedTo': staff});
    await load();
  }
}
