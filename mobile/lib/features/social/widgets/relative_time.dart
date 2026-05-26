/// Formats an ISO-8601 timestamp string into a short, human-facing relative
/// label ("just now", "3h", "2d", "5 May"). Shared by the stories feed and the
/// full-screen story viewer.
///
/// Tolerates null / unparseable input by returning an empty string, so callers
/// can render it unconditionally without a guard.
String relativeTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  DateTime? dt;
  try {
    dt = DateTime.parse(iso).toLocal();
  } catch (_) {
    return '';
  }

  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.isNegative) return 'just now';
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  // Older than a week — fall back to a calendar date.
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final monthName = months[(dt.month - 1).clamp(0, 11)];
  if (dt.year == now.year) return '${dt.day} $monthName';
  return '${dt.day} $monthName ${dt.year}';
}
