class Notice {
  Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.dateLabel,
    this.pinned = false,
    this.fromPlatform = false,
  });

  final String id;
  String title;
  String body;
  String dateLabel;
  bool pinned;

  /// Broadcast by Nestora from the super-admin panel. Shown with a tag, and
  /// the society admin cannot pin or delete it.
  final bool fromPlatform;

  factory Notice.fromJson(Map<String, dynamic> json, String dateLabel) {
    return Notice(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      pinned: (json['pinned'] as bool?) ?? false,
      fromPlatform: (json['fromPlatform'] as bool?) ?? false,
      dateLabel: dateLabel,
    );
  }
}
