import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../models/society.dart';

/// Raised when a structure edit would delete flats that still have records
/// attached. Carries the backend's impact report so the UI can spell out the
/// cost before the user commits to it.
class DestructiveChange implements Exception {
  DestructiveChange({
    required this.flatNumbers,
    required this.residents,
    required this.bills,
    required this.complaints,
    required this.deliveries,
    required this.preApproved,
    required this.bookings,
  });

  final List<String> flatNumbers;
  final int residents;
  final int bills;
  final int complaints;
  final int deliveries;
  final int preApproved;
  final int bookings;

  /// Reads the 409 body from `PATCH /societies/:id`, or null if [error] is
  /// some other failure.
  static DestructiveChange? tryParse(Object error) {
    if (error is! DioException) return null;
    final data = error.response?.data;
    if (data is! Map || data['code'] != 'DESTRUCTIVE_STRUCTURE_CHANGE') {
      return null;
    }
    final impact = (data['impact'] as Map?) ?? const {};
    int at(String key) => (impact[key] as num?)?.toInt() ?? 0;
    return DestructiveChange(
      flatNumbers: ((data['flatNumbers'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      residents: at('residents'),
      bills: at('bills'),
      complaints: at('complaints'),
      deliveries: at('deliveries'),
      preApproved: at('preApproved'),
      bookings: at('bookings'),
    );
  }

  /// Human-readable list of what would be lost, e.g. "1 resident, 10 bills".
  List<String> get losses {
    String plural(int n, String one, String many) =>
        '$n ${n == 1 ? one : many}';
    return [
      if (residents > 0) plural(residents, 'resident', 'residents'),
      if (bills > 0) plural(bills, 'bill', 'bills'),
      if (complaints > 0) plural(complaints, 'complaint', 'complaints'),
      if (deliveries > 0) plural(deliveries, 'delivery', 'deliveries'),
      if (preApproved > 0)
        plural(preApproved, 'pre-approved visitor', 'pre-approved visitors'),
      if (bookings > 0) plural(bookings, 'amenity booking', 'amenity bookings'),
    ];
  }
}

/// Loads and caches the current user's society from the backend.
///
/// The UI reads [society] synchronously after [load] has completed; mutations go
/// through the API and refresh the cache.
class SocietyRepository {
  SocietyRepository._();

  static final SocietyRepository instance = SocietyRepository._();

  final _api = ApiClient.instance;

  Society? _society;

  Society? get society => _society;

  bool get isConfigured => _society != null;

  /// Fetches the caller's society. A 403/404 (no society yet) leaves it null.
  ///
  /// A token minted before the admin's society existed carries `societyId=null`
  /// and 403s here even though a society now exists — so on failure we refresh
  /// the token once and retry before concluding there's no society.
  Future<void> load() async {
    try {
      final data = await _api.get('/societies/mine');
      _society = Society.fromJson(data as Map<String, dynamic>);
      return;
    } catch (_) {
      _society = null;
    }
    try {
      await AuthApi.instance.refresh();
      final data = await _api.get('/societies/mine');
      _society = Society.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      _society = null;
    }
  }

  /// Creates the society with the given per-tower per-floor flat counts.
  ///
  /// [hasTowers] false means one building: pass exactly one spec, and the
  /// backend numbers its flats 101, 102 instead of A101, A102.
  Future<void> create({
    required String name,
    required String address,
    required List<TowerSpec> towerSpecs,
    String? city,
    String? state,
    bool hasTowers = true,
  }) async {
    final data = await _api.post(
      '/societies',
      body: {
        'name': name,
        'address': address,
        'city': ?city,
        'state': ?state,
        'hasTowers': hasTowers,
        'towers': [
          for (final t in towerSpecs) {'flatsPerFloor': t.flatsPerFloor},
        ],
      },
    );
    _society = Society.fromJson(data as Map<String, dynamic>);
    // The society was just linked to this admin, but the login token still has
    // societyId=null. Refresh it so every society-scoped call now resolves.
    await AuthApi.instance.refresh();
  }

  /// Marks an argument the caller did not pass, which is NOT the same as
  /// passing null — null means "clear this field".
  static const Object _unset = Object();

  /// Updates the society's identity — name, address, logo. Never touches
  /// structure, so it can't hit the destructive-change path.
  ///
  /// [logoUrl] takes a url to set it, an explicit `null` to remove the picture,
  /// or nothing at all to leave it alone. Collapsing those last two is what
  /// made "Remove picture" silently do nothing.
  Future<void> updateProfile({
    String? name,
    String? address,
    String? city,
    String? state,
    Object? logoUrl = _unset,
  }) async {
    final id = _society?.id;
    if (id == null || id.isEmpty) {
      throw StateError('No society loaded to update');
    }
    final body = <String, dynamic>{
      'name': ?name,
      'address': ?address,
      // Sent as given: an empty string clears the field on the server.
      'city': ?city,
      'state': ?state,
    };
    if (!identical(logoUrl, _unset)) body['logoUrl'] = logoUrl;

    final data = await _api.patch('/societies/$id/profile', body: body);
    _society = Society.fromJson(data as Map<String, dynamic>);
  }

  /// Rewrites the tower/flat structure. Name and address are not editable here.
  ///
  /// [hasTowers] switches between one building and towers, which renumbers
  /// every flat — so it always trips [DestructiveChange] on a society that has
  /// any. Omit it to keep the current layout.
  ///
  /// Throws [DestructiveChange] if the edit would take existing records with
  /// it; call again with [force] once the user has accepted that.
  Future<void> update({
    required List<TowerSpec> towerSpecs,
    bool? hasTowers,
    bool force = false,
  }) async {
    final id = _society?.id;
    if (id == null || id.isEmpty) {
      throw StateError('No society loaded to update');
    }
    try {
      final data = await _api.patch(
        '/societies/$id',
        body: {
          'hasTowers': ?hasTowers,
          'towers': [
            for (final t in towerSpecs) {'flatsPerFloor': t.flatsPerFloor},
          ],
          if (force) 'force': true,
        },
      );
      _society = Society.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      final destructive = DestructiveChange.tryParse(e);
      if (destructive != null) throw destructive;
      rethrow;
    }
  }
}
