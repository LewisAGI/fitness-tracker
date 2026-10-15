const monthLabels = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String isoDate(DateTime value) {
  final day = dateOnly(value);
  final m = day.month.toString().padLeft(2, '0');
  final d = day.day.toString().padLeft(2, '0');
  return '${day.year}-$m-$d';
}

DateTime parseIsoDate(String value) {
  final parts = value.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

DateTime weekStart(DateTime value) {
  final day = dateOnly(value);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime lastCompletedWeekStart(DateTime now) {
  return weekStart(now).subtract(const Duration(days: 7));
}

String fmtDay(DateTime value) => '${value.day} ${monthLabels[value.month - 1]}';

String fmtDayYear(DateTime value) =>
    '${value.day} ${monthLabels[value.month - 1]} ${value.year}';

String fmtWeekdayDate(DateTime value) =>
    '${weekdayLabels[value.weekday - 1]} ${value.day} ${monthLabels[value.month - 1]}';

String fmtHm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

String fmtRange(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month) {
    return '${start.day}–${end.day} ${monthLabels[start.month - 1]} ${start.year}';
  }
  if (start.year == end.year) {
    return '${fmtDay(start)} – ${fmtDay(end)} ${start.year}';
  }
  return '${fmtDayYear(start)} – ${fmtDayYear(end)}';
}
