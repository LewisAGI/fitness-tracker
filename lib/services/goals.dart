import '../models/training.dart';
import 'normalise.dart';
import 'overload.dart';

/// A run matches a pace goal when the distances differ by at most this many km.
const paceDistanceToleranceKm = 0.05;

/// `5:30` or `5.5` minutes per kilometre. Returns seconds per km.
int? parsePaceMinPerKm(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return null;
  }
  final clock = RegExp(r'^(\d+):(\d{1,2})$').firstMatch(text);
  if (clock != null) {
    final minutes = int.parse(clock.group(1)!);
    final seconds = int.parse(clock.group(2)!);
    if (seconds >= 60 || minutes > 30) {
      return null;
    }
    final total = minutes * 60 + seconds;
    if (total <= 0) {
      return null;
    }
    return total;
  }
  final minutes = double.tryParse(text);
  if (minutes == null || minutes <= 0 || minutes > 30) {
    return null;
  }
  return (minutes * 60).round();
}

TrainingBias shapingBias(List<Goal> goals) {
  Goal? latest;
  for (final goal in goals) {
    if (goal.kind != GoalKind.general) {
      continue;
    }
    if (latest == null || goal.id > latest.id) {
      latest = goal;
    }
  }
  return biasFromGeneral(latest?.general);
}

String fmtClock(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final hours = safe ~/ 3600;
  final minutes = (safe % 3600) ~/ 60;
  final remain = safe % 60;
  final clock =
      '$minutes:${remain.toString().padLeft(2, '0')}';
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${remain.toString().padLeft(2, '0')}';
  }
  return clock;
}

int? runDurationSeconds(SetRow set, int? sessionDurationMin) {
  if (set.durationS != null && set.durationS! > 0) {
    return set.durationS;
  }
  if (sessionDurationMin != null && sessionDurationMin > 0) {
    return sessionDurationMin * 60;
  }
  return null;
}

int? paceSecondsPerKm(SetRow set, int? sessionDurationMin) {
  final distance = set.distanceKm;
  if (distance == null || distance <= 0) {
    return null;
  }
  final seconds = runDurationSeconds(set, sessionDurationMin);
  if (seconds == null) {
    return null;
  }
  return (seconds / distance).round();
}

bool paceDistanceMatches(double actualKm, double goalKm) =>
    (actualKm - goalKm).abs() <= paceDistanceToleranceKm;

List<String> paceFlagLines(Session session, List<Goal> goals) {
  final lines = <String>[];
  for (final set in session.sets) {
    lines.addAll(paceFlagLinesForSet(session, set, goals));
  }
  return lines;
}

List<String> paceFlagLinesForSet(Session session, SetRow set, List<Goal> goals) {
  final distance = set.distanceKm;
  final pace = paceSecondsPerKm(set, session.durationMin);
  if (distance == null || pace == null) {
    return const [];
  }
  final lines = <String>[];
  for (final goal in goals) {
    if (goal.kind != GoalKind.pace) {
      continue;
    }
    final goalKm = goal.distanceKm;
    final target = goal.targetPaceS;
    if (goalKm == null || target == null) {
      continue;
    }
    if (!paceDistanceMatches(distance, goalKm)) {
      continue;
    }
    if (pace > target) {
      lines.add(
        'slow: ${fmtClock(pace)}/km at ${fmtKm(distance)} km, goal ${fmtClock(target)}/km',
      );
    }
  }
  return lines;
}

List<String> goalProgressLines(List<Goal> goals, List<Session> sessions) {
  final ordered = [...goals]..sort((a, b) {
    final byKind = _kindRank(a.kind).compareTo(_kindRank(b.kind));
    if (byKind != 0) {
      return byKind;
    }
    return a.id.compareTo(b.id);
  });
  return [for (final goal in ordered) _progressLine(goal, sessions)];
}

int _kindRank(GoalKind kind) => switch (kind) {
  GoalKind.general => 0,
  GoalKind.lift => 1,
  GoalKind.pace => 2,
};

String _progressLine(Goal goal, List<Session> sessions) {
  return switch (goal.kind) {
    GoalKind.general => _generalLine(goal, sessions),
    GoalKind.lift => _liftLine(goal, sessions),
    GoalKind.pace => _paceLine(goal, sessions),
  };
}

String _generalLine(Goal goal, List<Session> sessions) {
  final bias = biasFromGeneral(goal.general);
  final range = rangeForBias(bias);
  final counted = _setsInRange(sessions, range.low, range.high);
  final label = switch (goal.general) {
    'strength' => 'Strength',
    'fitness' => 'Fitness',
    'hypertrophy' => 'Hypertrophy',
    _ => 'Goal',
  };
  return '$label · ${counted.hit}/${counted.total} sets in ${range.low}-${range.high}';
}

({int hit, int total}) _setsInRange(
  List<Session> sessions,
  int low,
  int high,
) {
  var hit = 0;
  var total = 0;
  for (final session in sessions) {
    for (final set in session.sets) {
      if (set.reps == null || set.distanceKm != null) {
        continue;
      }
      final count = set.setCount ?? 1;
      if (count <= 0) {
        continue;
      }
      total += count;
      if (set.reps! >= low && set.reps! <= high) {
        hit += count;
      }
    }
  }
  return (hit: hit, total: total);
}

String _liftLine(Goal goal, List<Session> sessions) {
  double? best;
  for (final session in sessions) {
    for (final set in session.sets) {
      if (!_sameLift(set, goal) || set.weightKg == null) {
        continue;
      }
      if (best == null || set.weightKg! > best) {
        best = set.weightKg;
      }
    }
  }
  final name = goal.exerciseName ?? 'Exercise ${goal.exerciseId ?? ''}';
  final current = best == null ? '-' : fmtKg(best);
  final target = goal.targetKg == null ? '-' : fmtKg(goal.targetKg!);
  return '$name · $current / $target kg';
}

bool _sameLift(SetRow set, Goal goal) {
  if (goal.exerciseId != null && set.exerciseId != null) {
    return set.exerciseId == goal.exerciseId;
  }
  final wanted = goal.exerciseName?.toLowerCase();
  final actual = set.exerciseName?.toLowerCase();
  return wanted != null && wanted == actual;
}

String _paceLine(Goal goal, List<Session> sessions) {
  final distance = goal.distanceKm;
  final target = goal.targetPaceS;
  final distanceLabel = distance == null ? '-' : '${fmtKm(distance)} km';
  final targetLabel = target == null ? '-' : '${fmtClock(target)}/km';
  final best = _bestPace(goal, sessions);
  if (best == null) {
    return '$distanceLabel · goal $targetLabel';
  }
  final mark = target != null && best <= target ? 'met' : 'slow';
  return '$distanceLabel · ${fmtClock(best)}/km · goal $targetLabel · $mark';
}

int? _bestPace(Goal goal, List<Session> sessions) {
  final distance = goal.distanceKm;
  if (distance == null) {
    return null;
  }
  int? best;
  for (final session in sessions) {
    for (final set in session.sets) {
      final actual = set.distanceKm;
      if (actual == null || !paceDistanceMatches(actual, distance)) {
        continue;
      }
      final pace = paceSecondsPerKm(set, session.durationMin);
      if (pace == null) {
        continue;
      }
      if (best == null || pace < best) {
        best = pace;
      }
    }
  }
  return best;
}
