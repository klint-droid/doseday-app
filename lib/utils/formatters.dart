const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _two(int v) => v.toString().padLeft(2, '0');

/// yyyy-MM-dd
String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// HH:mm
String timeKey(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// "08:30" -> "8:30 AM"
String formatTime(String time) {
  final p = time.split(':');
  if (p.length != 2) return time;
  final h = int.tryParse(p[0]) ?? 0;
  final m = int.tryParse(p[1]) ?? 0;
  final hour = h % 12 == 0 ? 12 : h % 12;
  return '$hour:${_two(m)} ${h < 12 ? 'AM' : 'PM'}';
}

/// "Saturday, October 24"
String friendlyDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

/// "2026-10-24" -> "Oct 24, 2026"
String shortDate(String key) {
  final d = DateTime.tryParse(key);
  if (d == null) return key;
  return '${_months[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}';
}

/// Single-letter weekday label for charts.
String weekdayLetter(DateTime d) => _weekdays[d.weekday - 1].substring(0, 1);

/// Parses "HH:mm" into (hour, minute), or null if invalid.
(int, int)? parseTime(String time) {
  final p = time.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return (h, m);
}
