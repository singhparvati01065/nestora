class MaintenanceBill {
  MaintenanceBill({
    required this.id,
    required this.flatNumber,
    required this.period,
    required this.amount,
    this.paid = false,
    this.kind = 'MANUAL',
    this.title,
    this.paidAt,
    this.dueDate,
  });

  final String id;
  final String flatNumber;
  final String period; // e.g. "Jul 2026"
  final double amount;
  bool paid;

  /// The day this bill is due (e.g. the move-in day for rent). Null for older
  /// bills — the UI falls back to just the [period].
  final DateTime? dueDate;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "10 Jul 2026" when a due date is known, else the plain "Jul 2026" period.
  String get dueLabel {
    final d = dueDate?.toLocal();
    if (d == null) return period;
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  /// 'RENT' (auto-generated monthly) or 'MANUAL' (an admin-added charge).
  final String kind;

  /// When it was paid. Bills paid together share the exact same value, which is
  /// how the history groups a single payment.
  final DateTime? paidAt;

  /// Name of an OTHER (custom) charge, e.g. "Parking". Null for rent/maintenance.
  final String? title;

  bool get isRent => kind == 'RENT';
  bool get isOther => kind == 'OTHER';

  /// What to call this bill: rent, maintenance, or the custom name of an
  /// "other" charge.
  String get kindLabel => isRent
      ? 'Rent'
      : isOther
          ? (title?.trim().isNotEmpty == true ? title!.trim() : 'Other')
          : 'Maintenance';

  factory MaintenanceBill.fromJson(Map<String, dynamic> json) {
    return MaintenanceBill(
      id: json['id'] as String,
      flatNumber: (json['flat']?['number'] ?? '') as String,
      period: json['period'] as String,
      // Prisma serialises Decimal as a string.
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      paid: (json['paid'] as bool?) ?? false,
      kind: (json['kind'] as String?) ?? 'MANUAL',
      title: json['title'] as String?,
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'] as String)?.toLocal()
          : null,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)?.toLocal()
          : null,
    );
  }
}
