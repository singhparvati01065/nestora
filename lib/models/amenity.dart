import 'package:flutter/material.dart';

/// Maps a backend icon key (e.g. "pool") to a Material icon.
IconData amenityIcon(String key) {
  switch (key) {
    case 'deck':
      return Icons.deck_outlined;
    case 'pool':
      return Icons.pool_outlined;
    case 'fitness_center':
      return Icons.fitness_center_outlined;
    case 'celebration':
      return Icons.celebration_outlined;
    case 'sports_tennis':
      return Icons.sports_tennis_outlined;
    case 'grass':
      return Icons.grass_outlined;
    case 'sports_soccer':
      return Icons.sports_soccer_outlined;
    case 'local_parking':
      return Icons.local_parking_outlined;
    case 'meeting_room':
      return Icons.meeting_room_outlined;
    case 'child_care':
      return Icons.child_care_outlined;
    case 'local_library':
      return Icons.local_library_outlined;
    case 'sports_cricket':
      return Icons.sports_cricket_outlined;
    default:
      return Icons.event_available_outlined;
  }
}

/// The icon keys an admin can pick from when adding an amenity.
const List<String> kAmenityIconKeys = [
  'deck',
  'pool',
  'fitness_center',
  'celebration',
  'sports_tennis',
  'sports_cricket',
  'sports_soccer',
  'grass',
  'local_parking',
  'meeting_room',
  'child_care',
  'local_library',
  'event_available',
];

class Amenity {
  const Amenity({required this.id, required this.name, required this.iconKey});

  final String id;
  final String name;
  final String iconKey;

  IconData get icon => amenityIcon(iconKey);

  factory Amenity.fromJson(Map<String, dynamic> json) {
    return Amenity(
      id: json['id'] as String,
      name: json['name'] as String,
      iconKey: (json['icon'] ?? '') as String,
    );
  }
}

class AmenityBooking {
  AmenityBooking({
    required this.id,
    required this.amenity,
    required this.flatNumber,
    required this.day,
    required this.slot,
    required this.status,
  });

  final String id;
  final String amenity;
  final String flatNumber;

  /// ISO date the booking is for, e.g. "2026-07-25".
  final String day;
  final String slot;

  /// 'PENDING' | 'APPROVED' | 'REJECTED'.
  final String status;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "25 Jul 2026" from [day], or the raw string if it isn't a date.
  String get dateLabel {
    final d = DateTime.tryParse(day);
    if (d == null) return day;
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  String get statusLabel => isApproved
      ? 'Approved'
      : isRejected
          ? 'Rejected'
          : 'Pending';

  factory AmenityBooking.fromJson(Map<String, dynamic> json) {
    return AmenityBooking(
      id: json['id'] as String,
      amenity: (json['amenity']?['name'] ?? '') as String,
      flatNumber: (json['flat']?['number'] ?? '') as String,
      day: json['day'] as String,
      slot: json['slot'] as String,
      status: (json['status'] ?? 'PENDING') as String,
    );
  }
}
