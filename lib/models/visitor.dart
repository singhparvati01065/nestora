import '../utils/time_format.dart';

class Visitor {
  Visitor({
    required this.id,
    required this.name,
    required this.phone,
    required this.flatNumber,
    required this.purpose,
    required this.inTime,
    required this.inside,
    this.inAt,
    this.vehicleNo,
    this.outTime,
  });

  final String id;
  String name;
  String phone;
  String flatNumber;
  String purpose;
  String? vehicleNo;
  String inTime;
  String? outTime;

  /// When they entered (full timestamp), for date filters like "today".
  final DateTime? inAt;

  /// Still on the premises (no exit recorded).
  bool inside;

  bool get isToday {
    final at = inAt?.toLocal();
    if (at == null) return false;
    final now = DateTime.now();
    return at.year == now.year && at.month == now.month && at.day == now.day;
  }

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  factory Visitor.fromJson(Map<String, dynamic> json) {
    final out = clockLabelFromIso(json['outAt'] as String?);
    return Visitor(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: (json['phone'] ?? '') as String,
      flatNumber: (json['flat']?['number'] ?? '') as String,
      purpose: json['purpose'] as String,
      vehicleNo: json['vehicleNo'] as String?,
      inTime: clockLabelFromIso(json['inAt'] as String?),
      inAt: DateTime.tryParse((json['inAt'] ?? '') as String)?.toLocal(),
      outTime: out.isEmpty ? null : out,
      inside: (json['status'] as String?) == 'INSIDE',
    );
  }
}
