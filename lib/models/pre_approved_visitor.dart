/// A visitor a resident has pre-approved. The guard can check them in with one
/// tap when they arrive at the gate.
class PreApprovedVisitor {
  PreApprovedVisitor({
    required this.id,
    required this.name,
    required this.flatNumber,
    required this.purpose,
    required this.validLabel,
    this.checkedIn = false,
  });

  final String id;
  String name;
  String flatNumber;
  String purpose;
  String validLabel; // e.g. "Today, till 6 PM"
  bool checkedIn;

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  factory PreApprovedVisitor.fromJson(Map<String, dynamic> json) {
    return PreApprovedVisitor(
      id: json['id'] as String,
      name: json['name'] as String,
      flatNumber: (json['flat']?['number'] ?? '') as String,
      purpose: json['purpose'] as String,
      validLabel: json['validLabel'] as String,
      checkedIn: (json['checkedIn'] as bool?) ?? false,
    );
  }
}
