import 'dart:io';

import 'package:fitness_tracker/models/training.dart';
import 'package:fitness_tracker/services/balance.dart';

/// Run with TZ=Europe/London. 2026-10-25 is the London clock change.
/// Adding 168 hours to Monday 19 Oct lands on Sunday 25 Oct at 23:00, which
/// used to pull the following Monday out of its own week.
void main() {
  final probe = DateTime(2026, 10, 19).add(const Duration(days: 7));
  final clockStayedPut =
      probe.year == 2026 &&
      probe.month == 10 &&
      probe.day == 26 &&
      probe.hour == 0;
  if (clockStayedPut) {
    stderr.writeln(
      'Europe/London did not move 19 Oct + 7 days; got $probe ${probe.timeZoneName}',
    );
    exit(2);
  }

  const chest = SetRow(
    exerciseName: 'Bench press',
    muscleGroups: ['chest'],
    setCount: 4,
    reps: 8,
    weightKg: 70,
  );
  final reports = balanceReports(
    start: DateTime(2026, 10, 1),
    end: DateTime(2026, 10, 31),
    splitWeeks: true,
    sessions: const [
      Session(date: '2026-10-25', type: 'gym', sets: [chest]),
      Session(date: '2026-10-26', type: 'gym', sets: [chest]),
    ],
  );
  final byStart = {for (final report in reports) report.start: report};
  final sundayWeek = byStart[DateTime(2026, 10, 19)];
  final mondayWeek = byStart[DateTime(2026, 10, 26)];
  if (sundayWeek == null || sundayWeek.end != DateTime(2026, 10, 25)) {
    stderr.writeln(
      'Sunday 25 Oct was not kept in the week of 19 Oct: $byStart',
    );
    exit(3);
  }
  if (mondayWeek == null) {
    stderr.writeln('Monday 26 Oct was dropped from the month: $byStart');
    exit(4);
  }
  if (mondayWeek.start.weekday != DateTime.monday ||
      mondayWeek.muscles.single.sets != 4) {
    stderr.writeln('Monday week was $mondayWeek start ${mondayWeek.start}');
    exit(5);
  }
}
