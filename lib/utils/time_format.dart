/// Formats [time] as a 12-hour clock label like "9:05 AM".
String clockLabel(DateTime time) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final ampm = time.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $ampm';
}

/// Clock label from an ISO timestamp string (returns '' when null/blank).
String clockLabelFromIso(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  return dt == null ? '' : clockLabel(dt.toLocal());
}

/// Short relative label like "Just now", "2h ago", "3d ago" from an ISO string.
String relativeLabelFromIso(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) return '${weeks}w ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}
