class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      read: (json['read'] as bool?) ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String)?.toLocal(),
    );
  }
}
