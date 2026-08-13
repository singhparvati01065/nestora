import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/resident.dart';

/// Residents directory, backed by the API. The UI reads [all] after [load].
///
/// A [ChangeNotifier] so any screen (the list, a tower's flat) rebuilds when the
/// roster changes from anywhere — e.g. removing a resident from a tower flat is
/// reflected on the Residents tab too.
class ResidentsRepository extends ChangeNotifier {
  ResidentsRepository._();
  static final ResidentsRepository instance = ResidentsRepository._();

  final _api = ApiClient.instance;
  List<Resident> _residents = [];

  List<Resident> get all => List.unmodifiable(_residents);

  /// The active resident living in [flatId], or null if the flat is empty.
  Resident? byFlatId(String flatId) {
    for (final r in _residents) {
      if (r.flatId == flatId) return r;
    }
    return null;
  }

  Future<void> load() async {
    final data = await _api.get('/residents') as List;
    _residents = data
        .map((e) => Resident.fromJson(e as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> add({
    required String name,
    required String phone,
    required String flatId,
    required ResidentType type,
    DateTime? moveInDate,
    double? rent,
    double? advance,
    double? maintenance,
    String? occupation,
    int? familyMembers,
    List<String> documentUrls = const [],
  }) async {
    await _api.post(
      '/residents',
      body: {
        'name': name,
        'phone': phone,
        'flatId': flatId,
        'type': type.api,
        if (moveInDate != null)
          'moveInDate': moveInDate.toIso8601String().split('T').first,
        'monthlyRent': ?rent,
        'advanceAmount': ?advance,
        'maintenanceAmount': ?maintenance,
        'occupation': ?occupation,
        'familyMembers': ?familyMembers,
        if (documentUrls.isNotEmpty) 'documentUrls': documentUrls,
      },
    );
    await load();
  }

  /// Unlike the other fields, [monthlyRent] and [advance] are always sent —
  /// null included. An owner pays neither, so switching a tenant to an owner has
  /// to erase what they had rather than silently leaving the old amounts.
  Future<void> update(
    Resident resident, {
    String? name,
    String? phone,
    ResidentType? type,
    double? monthlyRent,
    DateTime? moveInDate,
    double? advance,
    double? maintenance,
    String? occupation,
    int? familyMembers,
    List<String>? documentUrls,
  }) async {
    await _api.patch(
      '/residents/${resident.id}',
      body: {
        'name': ?name,
        'phone': ?phone,
        if (type != null) 'type': type.api,
        'monthlyRent': monthlyRent,
        if (moveInDate != null)
          'moveInDate': moveInDate.toIso8601String().split('T').first,
        'advanceAmount': advance,
        'maintenanceAmount': ?maintenance,
        'occupation': ?occupation,
        'familyMembers': ?familyMembers,
        'documentUrls': ?documentUrls,
      },
    );
    await load();
  }

  /// Soft delete — moves the resident to history, keeping the record.
  Future<void> archive(Resident resident) async {
    await _api.patch('/residents/${resident.id}/archive');
    await load();
  }

  /// The removed (archived) residents — history, newest first.
  Future<List<Resident>> fetchArchived() async {
    final data = await _api.get('/residents/archived') as List;
    return data
        .map((e) => Resident.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Permanently deletes a resident (from history).
  Future<void> remove(Resident resident) async {
    await _api.delete('/residents/${resident.id}');
  }
}
