const List<String> kMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const List<String> kWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "Saturday, 31 October"
String longDate(DateTime d) => '${kWeekdays[d.weekday - 1]}, ${d.day} ${kMonths[d.month - 1]}';

/// "Fri, 30 October"
String shortDate(DateTime d) =>
    '${kWeekdays[d.weekday - 1].substring(0, 3)}, ${d.day} ${kMonths[d.month - 1]}';

/// Whole days since epoch for the calendar day of [d] (timezone safe).
int dayNum(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String compactCount(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

String mmss(double seconds) {
  final s = seconds.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
