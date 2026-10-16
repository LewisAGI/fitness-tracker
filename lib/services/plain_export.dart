import '../models/training.dart';
import 'balance.dart';
import 'dates.dart';
import 'goals.dart';
import 'normalise.dart';

String buildPlainText({
  required String kind,
  required DateTime start,
  required DateTime end,
  required List<Session> sessions,
  required List<CheckIn> checkins,
  required List<Goal> goals,
  required List<StoredSuggestion> suggestions,
}) {
  final blocks = <String>['# Fitness Tracker\n${_scopeLine(kind, start, end)}'];
  final orderedSessions = [...sessions]..sort(_compareSessions);
  if (orderedSessions.isNotEmpty) {
    blocks.add(
      orderedSessions
          .map((session) => _sessionBlock(session, goals))
          .join('\n\n'),
    );
  }
  final orderedChecks = [...checkins]..sort(_compareChecks);
  if (orderedChecks.isNotEmpty) {
    blocks.add('## Check-ins\n${orderedChecks.map(_checkLine).join('\n')}');
  }
  if (kind == 'week' || kind == 'month') {
    final reports = balanceReports(
      start: start,
      end: end,
      sessions: orderedSessions,
      splitWeeks: kind == 'month',
    );
    if (reports.isNotEmpty) {
      blocks.add('## Balance\n${reports.map(_balanceBlock).join('\n\n')}');
    }
  }
  if (goals.isNotEmpty) {
    final lines = goalProgressLines(goals, orderedSessions);
    if (lines.isNotEmpty) {
      blocks.add('## Goals\n${lines.join('\n')}');
    }
  }
  if ((kind == 'week' || kind == 'month') && suggestions.isNotEmpty) {
    blocks.add(
      '## Next week\n${suggestions.map((suggestion) => suggestion.card).join('\n')}',
    );
  }
  return '${blocks.join('\n\n')}\n';
}

String _scopeLine(String kind, DateTime start, DateTime end) {
  final range = fmtRange(start, end);
  return switch (kind) {
    'workout' => 'Workout · ${fmtWeekdayDate(start)}',
    'day' => 'Day · ${fmtWeekdayDate(start)}',
    'month' => 'Month · $range',
    _ => 'Week · $range',
  };
}

int _compareSessions(Session a, Session b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) {
    return byDate;
  }
  final byTime = (a.startTime ?? '').compareTo(b.startTime ?? '');
  if (byTime != 0) {
    return byTime;
  }
  return a.id.compareTo(b.id);
}

int _compareChecks(CheckIn a, CheckIn b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) {
    return byDate;
  }
  return _slotRank(a.slot).compareTo(_slotRank(b.slot));
}

int _slotRank(String slot) => switch (slot) {
  'morning' => 0,
  'evening' => 1,
  _ => 2,
};

String _sessionBlock(Session session, List<Goal> goals) {
  final lines = <String>[_sessionHeading(session)];
  for (final set in session.sets) {
    if (_setHasContent(set)) {
      lines.add(_setLine(session, set));
    }
    lines.addAll(paceFlagLinesForSet(session, set, goals));
  }
  for (final block in session.blocks) {
    lines.add(_blockLine(block));
  }
  final notes = session.notes?.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (notes != null && notes.isNotEmpty) {
    lines.add('Notes: $notes');
  }
  return lines.join('\n');
}

String _sessionHeading(Session session) {
  final when = session.startTime == null || session.startTime!.isEmpty
      ? session.date
      : '${session.date} ${session.startTime}';
  final bits = <String>[when, _typeLabel(session.type)];
  if (session.durationMin != null) {
    bits.add('${session.durationMin} min');
  }
  if (session.rpe != null) {
    bits.add('RPE ${session.rpe}');
  }
  return '## ${bits.join(' · ')}';
}

bool _setHasContent(SetRow set) {
  if (set.distanceKm != null) {
    return true;
  }
  return set.reps != null || set.weightKg != null || set.bodyweight;
}

String _setLine(Session session, SetRow set) {
  if (set.distanceKm != null) {
    return _runLine(session, set);
  }
  final name = set.exerciseName ?? '?';
  final count = set.setCount ?? 1;
  final buffer = StringBuffer('$name · $count');
  if (set.reps != null) {
    buffer.write(' x ${set.reps}');
  }
  if (set.bodyweight) {
    buffer.write(' · bodyweight');
  } else if (set.weightKg != null) {
    buffer.write(' x ${fmtKg(set.weightKg!)} kg');
  }
  if (set.rir != null) {
    buffer.write(' · RIR ${set.rir}');
  }
  if (set.rpe != null) {
    buffer.write(' · RPE ${set.rpe}');
  }
  return buffer.toString();
}

String _runLine(Session session, SetRow set) {
  final name = set.exerciseName ?? 'Run';
  final bits = <String>[name, '${fmtKm(set.distanceKm!)} km'];
  final seconds = runDurationSeconds(set, session.durationMin);
  if (seconds != null && set.distanceKm! > 0) {
    bits.add(fmtClock(seconds));
    bits.add('${fmtClock((seconds / set.distanceKm!).round())}/km');
  }
  if (set.rpe != null) {
    bits.add('RPE ${set.rpe}');
  }
  return bits.join(' · ');
}

String _blockLine(SessionBlock block) {
  final name = (block.label == null || block.label!.isEmpty)
      ? _titleWord(block.subtype)
      : block.label!;
  final bits = <String>[
    name,
    if (block.durationMin != null) '${block.durationMin} min',
    'RPE ${block.rpe}',
  ];
  return bits.join(' · ');
}

String _checkLine(CheckIn checkIn) {
  final bits = <String>['${checkIn.date} · ${_slotLabel(checkIn.slot)}'];
  void add(String name, Object? value) {
    if (value != null) {
      bits.add('$name $value');
    }
  }

  add('soreness', checkIn.soreness);
  add('energy', checkIn.energy);
  add('sleep', checkIn.sleepQuality);
  add('hours', checkIn.sleepHours == null ? null : _trim(checkIn.sleepHours!));
  add('mood', checkIn.mood);
  add('stress', checkIn.stress);
  add('feel', checkIn.sessionFeel);
  add('ate', checkIn.ateWell);
  return bits.join(' · ');
}

String _balanceBlock(BalanceReport report) {
  final lines = <String>[
    fmtRange(report.start, report.end),
    for (final muscle in report.muscles) muscleLine(muscle),
    for (final flag in report.flags) flag,
  ];
  return lines.join('\n');
}

String _slotLabel(String slot) => switch (slot) {
  'morning' => 'Morning',
  'evening' => 'Evening',
  _ => _titleWord(slot),
};

String _typeLabel(String type) => switch (type) {
  'muay_thai' => 'Muay Thai',
  'gym' => 'Gym',
  'run' => 'Run',
  'hike' => 'Hike',
  'yoga' => 'Yoga',
  _ => 'Other',
};

String _titleWord(String raw) {
  if (raw.isEmpty) {
    return raw;
  }
  return '${raw[0].toUpperCase()}${raw.substring(1)}';
}

String _trim(double value) {
  if ((value - value.round()).abs() < 0.001) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
