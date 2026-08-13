/// One message on a ticket — from Nestora support, or from this society.
class TicketReply {
  TicketReply({
    required this.body,
    required this.author,
    this.fromSupport = true,
    this.createdAt,
  });

  final String body;
  final String author;

  /// True when Nestora support wrote it; false for this society's own reply.
  final bool fromSupport;

  final DateTime? createdAt;

  factory TicketReply.fromJson(Map<String, dynamic> json) => TicketReply(
    body: (json['body'] ?? '') as String,
    author: (json['author'] ?? 'Nestora Support') as String,
    fromSupport: (json['fromSupport'] as bool?) ?? true,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String)?.toLocal()
        : null,
  );
}

/// A support ticket raised by the society admin.
class SupportTicket {
  SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.message,
    required this.status,
    this.replies = const [],
    this.createdAt,
  });

  final String id;
  final String category;
  final String subject;
  final String message;

  /// 'OPEN' | 'PENDING' | 'CLOSED'.
  final String status;

  /// Support's answers, oldest first.
  final List<TicketReply> replies;

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
    replies: ((json['replies'] as List?) ?? const [])
        .map((e) => TicketReply.fromJson(e as Map<String, dynamic>))
        .toList(),
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
