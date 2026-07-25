/// A support ticket raised by the society admin.
class SupportTicket {
  SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.message,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String category;
  final String subject;
  final String message;

  /// 'OPEN' | 'PENDING' | 'CLOSED'.
  final String status;
  final DateTime? createdAt;

  String get statusLabel {
    switch (status) {
      case 'CLOSED':
        return 'Closed';
      case 'PENDING':
        return 'Pending';
      default:
        return 'Open';
    }
  }

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] as String,
        category: (json['category'] ?? '') as String,
        subject: (json['subject'] ?? '') as String,
        message: (json['message'] ?? '') as String,
        status: (json['status'] ?? 'OPEN') as String,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)?.toLocal()
            : null,
      );
}

/// Categories a society admin can raise a ticket under.
const List<String> kTicketCategories = [
  'Payment Issue',
  'Visitor Bug',
  'Login Problem',
  'Other',
];
