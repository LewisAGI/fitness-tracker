import '../models/training.dart';
import 'dates.dart';
import 'normalise.dart';

/// The heavier muscle must reach this many sets before a split is flagged.
const balanceHeavyMinSets = 6;

/// Flag when the lighter muscle has at most this percent of the heavier muscle's sets.
const balanceLightMaxPercent = 60;

/// Preference order is also the tie-break: earlier wins when set counts match.
const upperMuscles = [
  'chest',
  'back',
  'shoulders',
  'biceps',
  'triceps',
  'traps',
  'forearms',
];
const lowerMuscles = ['legs', 'quads', 'hamstrings', 'glutes', 'calves'];
const pushMuscles = ['chest', 'shoulders', 'triceps'];
const pullMuscles = ['back', 'biceps', 'traps'];
const frontMuscles = ['chest', 'quads', 'shoulders', 'biceps', 'core'];
const backChainMuscles = [
  'back',
  'hamstrings',
  'glutes',
  'traps',
  'calves',
  'triceps',
];

class MuscleLoad {
  const MuscleLoad({
    required this.muscle,
    required this.sets,
    required this.volumeKg,
  });

  final String muscle;
  final int sets;
  final double volumeKg;
}

class BalanceReport {
  const BalanceReport({
    required this.start,
    required this.end,
    required this.muscles,
    required this.flags,
  });

  final DateTime start;
  final DateTime end;
  final List<MuscleLoad> muscles;
  final List<String> flags;

  bool get isEmpty => muscles.isEmpty && flags.isEmpty;
}

class _Side {
  const _Side(this.name, this.emptyLabel, this.muscles);

  final String name;
  final String emptyLabel;
  final List<String> muscles;
}

const _splits = [
  (_Side('upper', 'chest', upperMuscles), _Side('lower', 'legs', lowerMuscles)),
  (_Side('push', 'push', pushMuscles), _Side('pull', 'pull', pullMuscles)),
  (
    _Side('front', 'front', frontMuscles),
    _Side('back', 'back', backChainMuscles),
  ),
];

class _Tally {
  int sets = 0;
  double volume = 0;
}

/// Weekly sets and volume. A month is one report per Monday–Sunday week.
List<BalanceReport> balanceReports({
  required DateTime start,
  required DateTime end,
  required List<Session> sessions,
  required bool splitWeeks,
}) {
  if (!splitWeeks) {
    final report = buildBalance(start: start, end: end, sessions: sessions);
    return report.isEmpty ? const [] : [report];
  }
  final reports = <BalanceReport>[];
  final last = dateOnly(end);
  var cursor = weekStart(start);
  while (!cursor.isAfter(last)) {
    final weekEnd = _calendarDays(cursor, 6);
    final from = cursor.isBefore(dateOnly(start)) ? dateOnly(start) : cursor;
    final to = weekEnd.isAfter(last) ? last : weekEnd;
    final slice = [
      for (final session in sessions)
        if (_inRange(session.date, from, to)) session,
    ];
    final report = buildBalance(start: from, end: to, sessions: slice);
    if (!report.isEmpty) {
      reports.add(report);
    }
    cursor = _calendarDays(cursor, 7);
  }
  return reports;
}

/// Calendar days, not 24-hour steps. A clock change must not land Monday on Sunday.
DateTime _calendarDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

bool _inRange(String iso, DateTime start, DateTime end) {
  final day = parseIsoDate(iso);
  return !day.isBefore(start) && !day.isAfter(end);
}

BalanceReport buildBalance({
  required DateTime start,
  required DateTime end,
  required List<Session> sessions,
}) {
  final tallies = <String, _Tally>{};
  for (final session in sessions) {
    for (final set in session.sets) {
      _addSet(tallies, set);
    }
  }
  final muscles =
      [
        for (final entry in tallies.entries)
          MuscleLoad(
            muscle: entry.key,
            sets: entry.value.sets,
            volumeKg: entry.value.volume,
          ),
      ]..sort((a, b) {
        final bySets = b.sets.compareTo(a.sets);
        if (bySets != 0) {
          return bySets;
        }
        return a.muscle.compareTo(b.muscle);
      });
  final flags = <String>[];
  for (final split in _splits) {
    final flag = _flag(tallies, split.$1, split.$2);
    if (flag != null) {
      flags.add(flag);
    }
  }
  return BalanceReport(
    start: dateOnly(start),
    end: dateOnly(end),
    muscles: muscles,
    flags: flags,
  );
}

void _addSet(Map<String, _Tally> tallies, SetRow set) {
  if (set.distanceKm != null) {
    return;
  }
  if (set.reps == null && set.weightKg == null) {
    return;
  }
  final count = set.setCount ?? 1;
  if (count <= 0) {
    return;
  }
  final volume = count * (set.reps ?? 0) * (set.weightKg ?? 0);
  final seen = <String>{};
  for (final raw in set.muscleGroups) {
    final muscle = raw.toLowerCase();
    if (muscle.isEmpty || muscle == 'full' || !seen.add(muscle)) {
      continue;
    }
    final tally = tallies.putIfAbsent(muscle, _Tally.new);
    tally.sets += count;
    tally.volume += volume;
  }
}

String? _flag(Map<String, _Tally> tallies, _Side left, _Side right) {
  final leftBest = _busiest(tallies, left.muscles);
  final rightBest = _busiest(tallies, right.muscles);
  final leftSets = leftBest?.sets ?? 0;
  final rightSets = rightBest?.sets ?? 0;
  if (leftSets == 0 && rightSets == 0) {
    return null;
  }
  if (leftSets == rightSets) {
    return null;
  }
  final heavyLeft = leftSets > rightSets;
  final heavySets = heavyLeft ? leftSets : rightSets;
  final lightSets = heavyLeft ? rightSets : leftSets;
  if (heavySets < balanceHeavyMinSets) {
    return null;
  }
  if (lightSets * 100 > heavySets * balanceLightMaxPercent) {
    return null;
  }
  final heavyName = heavyLeft
      ? (leftBest?.name ?? left.emptyLabel)
      : (rightBest?.name ?? right.emptyLabel);
  final lightName = heavyLeft
      ? (rightBest?.name ?? right.emptyLabel)
      : (leftBest?.name ?? left.emptyLabel);
  final heavySide = heavyLeft ? left.name : right.name;
  final pct = _percent(lightSets, heavySets);
  return '$heavySide-heavy: $lightName got $pct% of the sets $heavyName got';
}

({String name, int sets})? _busiest(
  Map<String, _Tally> tallies,
  List<String> preference,
) {
  String? name;
  var sets = 0;
  var rank = preference.length;
  for (var i = 0; i < preference.length; i++) {
    final muscle = preference[i];
    final count = tallies[muscle]?.sets ?? 0;
    if (count <= 0) {
      continue;
    }
    if (count > sets || (count == sets && i < rank)) {
      name = muscle;
      sets = count;
      rank = i;
    }
  }
  if (name == null) {
    return null;
  }
  return (name: name, sets: sets);
}

int _percent(int light, int heavy) {
  if (heavy <= 0) {
    return 0;
  }
  final scaled = light * 100;
  final whole = scaled ~/ heavy;
  final remainder = scaled % heavy;
  if (remainder * 2 >= heavy) {
    return whole + 1;
  }
  return whole;
}

String muscleLine(MuscleLoad load) {
  final noun = load.sets == 1 ? 'set' : 'sets';
  return '${load.muscle} · ${load.sets} $noun · ${fmtKg(load.volumeKg)} kg';
}

class RegionBar {
  const RegionBar({
    required this.label,
    required this.sets,
    required this.neglected,
  });

  final String label;
  final int sets;

  /// Strictly below the busiest region. The accent is reserved for these.
  final bool neglected;
}

/// Push, pull, and legs use the busiest listed muscle. Core uses core sets.
List<RegionBar> regionBars(BalanceReport report) {
  final rows = [
    ('Push', _regionSets(report, pushMuscles)),
    ('Pull', _regionSets(report, pullMuscles)),
    ('Legs', _regionSets(report, lowerMuscles)),
    ('Core', _namedSets(report, 'core')),
  ];
  var busiest = 0;
  for (final row in rows) {
    if (row.$2 > busiest) {
      busiest = row.$2;
    }
  }
  return [
    for (final row in rows)
      RegionBar(
        label: row.$1,
        sets: row.$2,
        neglected: busiest > 0 && row.$2 < busiest,
      ),
  ];
}

int _regionSets(BalanceReport report, List<String> muscles) {
  var best = 0;
  for (final muscle in muscles) {
    final sets = _namedSets(report, muscle);
    if (sets > best) {
      best = sets;
    }
  }
  return best;
}

int _namedSets(BalanceReport report, String muscle) {
  for (final load in report.muscles) {
    if (load.muscle == muscle) {
      return load.sets;
    }
  }
  return 0;
}
