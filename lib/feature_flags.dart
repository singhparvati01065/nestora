import 'dart:async';

import 'api/api_client.dart';

/// Platform-wide module switches, owned by the super-admin panel.
///
/// Fetched once at launch from `GET /feature-flags` (a public route, so it
/// works before login) and read synchronously while building screens. The API
/// enforces the same flags, so hiding an entry point here is presentation —
/// never the only thing standing between a user and a disabled module.
///
/// An unknown or unfetched flag reads as **on**: a network hiccup must not
/// blank out the app.
class FeatureFlags {
  FeatureFlags._();

  static final FeatureFlags instance = FeatureFlags._();

  Map<String, bool> _flags = const {};

  bool isOn(String key) => _flags[key] ?? true;

  /// Amenity listing and booking.
  bool get amenities => isOn('amenities');

  /// Raising and tracking complaints.
  bool get complaints => isOn('complaints');

  /// The gate: visitors, expected guests and parcels.
  bool get visitors => isOn('visitors');

  /// Bills and payments. The flag has been seeded as `online_payments` since
  /// the panel first shipped, so that is the key on the wire.
  bool get payments => isOn('online_payments');

  /// Refreshes the flags. Never throws — on failure the last known values (or
  /// the all-on default) stay in place.
  Future<void> load() async {
    try {
      // Launch waits on this, so it gets a shorter leash than the client's
      // default timeouts: a slow network delays the app, it must not stall it.
      final data = await ApiClient.instance
          .get('/feature-flags')
          .timeout(const Duration(seconds: 4));
      if (data is Map) {
        _flags = {
          for (final entry in data.entries)
            if (entry.value is bool) entry.key.toString(): entry.value as bool,
        };
      }
    } catch (_) {
      // Offline or server down — keep serving what we have.
    }
  }
}
