class Notice {
  Notice({
    required this.id,
    required this.title,
    required this.body,
    required this.dateLabel,
    this.pinned = false,
  });

  final String id;
  String title;
  String body;
  String dateLabel;
  bool pinned;

  factory Notice.fromJson(Map<String, dynamic> json, String dateLabel) {
    return Notice(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      pinned: (json['pinned'] as bool?) ?? false,
      dateLabel: dateLabel,
    );
  }
}
