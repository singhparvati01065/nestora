import '../utils/time_format.dart';

class Delivery {
  Delivery({
    required this.id,
    required this.courier,
    required this.flatNumber,
    required this.inTime,
    this.collected = false,
  });

  final String id;
  String courier;
  String flatNumber;
  String inTime;
  bool collected;

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'] as String,
      courier: json['courier'] as String,
      flatNumber: (json['flat']?['number'] ?? '') as String,
      collected: (json['collected'] as bool?) ?? false,
      inTime: clockLabelFromIso(json['inAt'] as String?),
    );
  }
}
