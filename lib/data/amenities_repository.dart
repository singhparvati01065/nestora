import '../api/api_client.dart';
import '../models/amenity.dart';

/// Society amenities and the resident's bookings, backed by the API.
class AmenitiesRepository {
  AmenitiesRepository._();
  static final AmenitiesRepository instance = AmenitiesRepository._();

  final _api = ApiClient.instance;

  /// Time slots offered for booking (client-side options).
  static const slots = [
    '6 AM - 8 AM',
    '8 AM - 10 AM',
    '10 AM - 12 PM',
    '4 PM - 6 PM',
    '6 PM - 8 PM',
    '8 PM - 10 PM',
  ];

  List<Amenity> _amenities = [];
  List<AmenityBooking> _bookings = [];

  List<Amenity> get amenities => List.unmodifiable(_amenities);
  List<AmenityBooking> get bookings => List.unmodifiable(_bookings);

  Future<void> load() async {
    await loadAmenities();
    final bookingsData = await _api.get('/amenities/bookings') as List;
    _bookings = bookingsData
        .map((e) => AmenityBooking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Just the amenities (no resident bookings) — for the admin, who can't hit
  /// the resident-only bookings route.
  Future<void> loadAmenities() async {
    final data = await _api.get('/amenities') as List;
    _amenities = data
        .map((e) => Amenity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// [day] is an ISO date, e.g. "2026-07-25".
  Future<void> book({
    required String amenityId,
    required String day,
    required String slot,
  }) async {
    await _api.post('/amenities/book',
        body: {'amenityId': amenityId, 'day': day, 'slot': slot});
    await load();
  }

  /// Slots already taken (pending/approved) for [amenityId] on [day].
  Future<List<String>> bookedSlots({
    required String amenityId,
    required String day,
  }) async {
    final data = await _api.get('/amenities/booked',
        query: {'amenityId': amenityId, 'day': day}) as List;
    return data.map((e) => e.toString()).toList();
  }

  Future<void> cancel(String bookingId) async {
    await _api.delete('/amenities/bookings/$bookingId');
    await load();
  }

  // ---- Admin ----

  Future<List<AmenityBooking>> allBookings() async {
    final data = await _api.get('/amenities/bookings/all') as List;
    return data
        .map((e) => AmenityBooking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createAmenity({
    required String name,
    required String icon,
  }) async {
    await _api.post('/amenities', body: {'name': name, 'icon': icon});
    await loadAmenities();
  }

  Future<void> updateAmenity(String id,
      {String? name, String? icon}) async {
    await _api.patch('/amenities/$id', body: {'name': ?name, 'icon': ?icon});
    await loadAmenities();
  }

  Future<void> deleteAmenity(String id) async {
    await _api.delete('/amenities/$id');
    await loadAmenities();
  }

  Future<void> setBookingStatus(String id, String status) async {
    await _api.patch('/amenities/bookings/$id/status',
        body: {'status': status});
  }
}
