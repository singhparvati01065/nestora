/// A staff login account the admin manages: a security guard or a maintenance
/// worker. Backed by the backend `User` table (roles SECURITY_GUARD /
/// MAINTENANCE_STAFF), so creating one here is what lets them log in.
class Staff {
  Staff({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.address,
    this.joinedAt,
    this.salary,
    this.trades = const [],
  });

  final String id;
  final String name;
  final String phone;
  final String? address;
  final DateTime? joinedAt;
  final double? salary;

  /// 'SECURITY_GUARD' or 'MAINTENANCE_STAFF'.
  final String role;

  /// Complaint categories a maintenance worker handles. Empty for guards.
  final List<String> trades;

  bool get isGuard => role == 'SECURITY_GUARD';
  String get roleLabel => isGuard ? 'Security Guard' : 'Maintenance Staff';

  factory Staff.fromJson(Map<String, dynamic> json) => Staff(
        id: json['id'] as String,
        name: (json['name'] ?? '') as String,
        phone: (json['phone'] ?? '') as String,
        address: json['address'] as String?,
        joinedAt: json['joinedAt'] != null
            ? DateTime.tryParse(json['joinedAt'] as String)?.toLocal()
            : null,
        // Prisma serialises Decimal as a string.
        salary: json['salary'] != null
            ? double.tryParse(json['salary'].toString())
            : null,
        role: json['role'] as String,
        trades: ((json['trades'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}
