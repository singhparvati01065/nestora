import '../api/api_client.dart';
import '../models/staff.dart';

/// The society's guards + maintenance staff, backed by the API. Creating a staff
/// member makes a login account for them; they then sign in with their number.
class StaffRepository {
  StaffRepository._();
  static final StaffRepository instance = StaffRepository._();

  final _api = ApiClient.instance;
  List<Staff> _staff = [];

  List<Staff> get all => List.unmodifiable(_staff);
  List<Staff> get guards => _staff.where((s) => s.isGuard).toList();
  List<Staff> get maintenance => _staff.where((s) => !s.isGuard).toList();

  Future<void> load() async {
    final data = await _api.get('/staff') as List;
    _staff = data
        .map((e) => Staff.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> create({
    required String role,
    required String name,
    required String phone,
    String? address,
    DateTime? joinedAt,
    double? salary,
    List<String>? trades,
  }) async {
    await _api.post('/staff', body: {
      'role': role,
      'name': name,
      'phone': phone,
      'address': ?address,
      'joinedAt': ?joinedAt?.toIso8601String().split('T').first,
      'salary': ?salary,
      'trades': ?trades,
    });
    await load();
  }

  Future<void> update(
    String id, {
    String? name,
    String? phone,
    String? address,
    DateTime? joinedAt,
    double? salary,
    List<String>? trades,
  }) async {
    await _api.patch('/staff/$id', body: {
      'name': ?name,
      'phone': ?phone,
      'address': address, // send explicit null to clear
      'joinedAt': ?joinedAt?.toIso8601String().split('T').first,
      'salary': salary, // explicit null clears it
      'trades': ?trades,
    });
    await load();
  }

  /// Soft-remove: moves the staff member to history (still recoverable by
  /// re-adding the same number).
  Future<void> archive(String id) async {
    await _api.patch('/staff/$id/archive');
    await load();
  }

  /// The removed (archived) staff — history, newest first.
  Future<List<Staff>> fetchArchived() async {
    final data = await _api.get('/staff/archived') as List;
    return data
        .map((e) => Staff.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Permanently deletes a staff account (from history).
  Future<void> remove(String id) async {
    await _api.delete('/staff/$id');
  }
}
