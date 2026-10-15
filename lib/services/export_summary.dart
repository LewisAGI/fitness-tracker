import 'dart:convert';

import '../models/training.dart';
import 'dates.dart';

class ExportSnapshot {
  const ExportSnapshot({
    required this.kind,
    required this.start,
    required this.end,
    required this.sessions,
    required this.plans,
    required this.checkins,
    required this.warnings,
    required this.patterns,
    required this.suggestions,
    this.readinessByDay = const {},
    this.fatigueByDay = const {},
  });

  final String kind;
  final DateTime start;
  final DateTime end;
  final List<Session> sessions;
  final List<PlanItem> plans;
  final List<CheckIn> checkins;
  final List<StoredWarning> warnings;
  final List<StoredPattern> patterns;
  final List<StoredSuggestion> suggestions;
  final Map<String, double> readinessByDay;
  final Map<String, double> fatigueByDay;
}

class ExportFiles {
  const ExportFiles({required this.json, required this.markdown});

  final String json;
  final String markdown;
}

ExportFiles buildExport(ExportSnapshot snapshot) {
  final sessions = snapshot.sessions.map(_sessionJson).toList();
  final plans = snapshot.plans.map(_planJson).toList();
  final actualByDay = <String, List<String>>{};
  for (final session in snapshot.sessions) {
    actualByDay.putIfAbsent(session.date, () => []).add(session.type);
  }
  final planByDay = <String, List<String>>{};
  for (final plan in snapshot.plans) {
    planByDay.putIfAbsent(plan.date, () => []).add(plan.type);
  }
  final days = {...actualByDay.keys, ...planByDay.keys}.toList()..sort();
  final planVsActual = [
    for (final day in days)
      {
        'date': day,
        'planned': planByDay[day] ?? const <String>[],
        'actual': actualByDay[day] ?? const <String>[],
      },
  ];
  final warnings = [
    for (final warning in snapshot.warnings)
      {
        'date': warning.date,
        'rule': warning.rule,
        'shown': warning.shown,
        'level': warning.level,
        'evidence': warning.evidence,
        'muscle_groups': warning.muscleGroups,
        'evidence_dates': warning.evidenceDates,
        'next_day_readiness': snapshot.readinessByDay[_nextDay(warning.date)],
        'next_day_fatigue': snapshot.fatigueByDay[_nextDay(warning.date)],
      },
  ];
  final body = {
    'schema': 'fitness-summary-v1',
    'kind': snapshot.kind,
    'range': {'start': isoDate(snapshot.start), 'end': isoDate(snapshot.end)},
    'sessions': sessions,
    'checkins': snapshot.checkins.map(_checkInJson).toList(),
    'plan': plans,
    'plan_vs_actual': planVsActual,
    'warnings': warnings,
    'patterns': [
      for (final pattern in snapshot.patterns)
        {
          'key': pattern.key,
          'n': pattern.n,
          'mean_next_readiness': pattern.meanNextReadiness,
          'mean_next_fatigue': pattern.meanNextFatigue,
          'last_updated': pattern.lastUpdated,
        },
    ],
    'overload_suggestions': [
      for (final suggestion in snapshot.suggestions)
        {
          'week_start': suggestion.weekStart,
          'exercise_id': suggestion.exerciseId,
          'exercise': suggestion.exerciseName,
          'working_weight_kg': suggestion.workingWeightKg,
          'reps': suggestion.repsCsv,
          'rep_low': suggestion.repLow,
          'rep_high': suggestion.repHigh,
          'action': suggestion.action,
          'suggested_weight_kg': suggestion.suggestedWeightKg,
          'aim_reps': suggestion.aimReps,
          'card': suggestion.card,
          'muscle_groups': suggestion.muscleGroups,
        },
    ],
  };
  return ExportFiles(
    json: const JsonEncoder.withIndent('  ').convert(body),
    markdown: _markdown(snapshot, planVsActual),
  );
}

String _nextDay(String iso) => isoDate(parseIsoDate(iso).add(const Duration(days: 1)));

String _slotLabel(String slot) {
  if (slot.isEmpty) {
    return slot;
  }
  return '${slot[0].toUpperCase()}${slot.substring(1)}';
}

Map<String, Object?> _sessionJson(Session session) => {
  'id': session.id,
  'date': session.date,
  'start_time': session.startTime,
  'type': session.type,
  'duration_min': session.durationMin,
  'rpe': session.rpe,
  'notes': session.notes,
  'raw_transcript': session.rawTranscript,
  'sets': [
    for (final set in session.sets)
      {
        'id': set.id,
        'exercise_id': set.exerciseId,
        'exercise': set.exerciseName,
        'set_count': set.setCount,
        'reps': set.reps,
        'weight_kg': set.weightKg,
        'distance_km': set.distanceKm,
        'duration_s': set.durationS,
        'rpe': set.rpe,
        'bodyweight': set.bodyweight,
      },
  ],
  'blocks': [
    for (final block in session.blocks)
      {
        'id': block.id,
        'subtype': block.subtype,
        'duration_min': block.durationMin,
        'rpe': block.rpe,
        'load': block.load,
      },
  ],
};

Map<String, Object?> _planJson(PlanItem plan) => {
  'id': plan.id,
  'date': plan.date,
  'type': plan.type,
  'muscle_groups': plan.muscleGroups,
  'intensity': plan.intensity,
  'duration_min_est': plan.durationMinEst,
  'suggestion': plan.suggestion,
};

Map<String, Object?> _checkInJson(CheckIn checkIn) => {
  'date': checkIn.date,
  'slot': checkIn.slot,
  'soreness': checkIn.soreness,
  'energy': checkIn.energy,
  'sleep_quality': checkIn.sleepQuality,
  'sleep_hours': checkIn.sleepHours,
  'mood': checkIn.mood,
  'stress': checkIn.stress,
  'session_feel': checkIn.sessionFeel,
  'ate_well': checkIn.ateWell,
  'raw_transcript': checkIn.rawTranscript,
};

String _markdown(
  ExportSnapshot snapshot,
  List<Map<String, Object?>> planVsActual,
) {
  final buffer = StringBuffer()
    ..writeln('# Fitness Tracker')
    ..writeln()
    ..writeln(fmtRange(snapshot.start, snapshot.end))
    ..writeln()
    ..writeln('## Sessions')
    ..writeln()
    ..writeln('| Date | Type | Duration | RPE | Detail |')
    ..writeln('| --- | --- | --- | --- | --- |');
  for (final session in snapshot.sessions) {
    final detail = [
      if (session.sets.isNotEmpty)
        session.sets
            .map((set) {
              final name = set.exerciseName ?? '?';
              final load = set.bodyweight
                  ? 'bodyweight'
                  : set.weightKg == null
                  ? ''
                  : '${set.weightKg} kg';
              return '$name ${set.setCount ?? 1}x${set.reps ?? '-'} $load'.trim();
            })
            .join('; '),
      if (session.blocks.isNotEmpty)
        session.blocks
            .map(
              (block) =>
                  '${block.subtype} ${block.durationMin} min RPE ${block.rpe} load ${block.load.round()}',
            )
            .join('; '),
    ].join(' ');
    buffer.writeln(
      '| ${session.date} | ${session.type} | ${session.durationMin ?? ''} | ${session.rpe ?? ''} | $detail |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Check-ins')
    ..writeln()
    ..writeln(
      '| Date | Slot | Soreness | Energy | Sleep quality | Sleep hours | Mood | Stress | Session feel | Ate well |',
    )
    ..writeln('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |');
  for (final checkIn in snapshot.checkins) {
    buffer.writeln(
      '| ${checkIn.date} | ${_slotLabel(checkIn.slot)} | ${checkIn.soreness ?? ''} | ${checkIn.energy ?? ''} | ${checkIn.sleepQuality ?? ''} | ${checkIn.sleepHours ?? ''} | ${checkIn.mood ?? ''} | ${checkIn.stress ?? ''} | ${checkIn.sessionFeel ?? ''} | ${checkIn.ateWell ?? ''} |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Plan vs actual')
    ..writeln()
    ..writeln('| Date | Planned | Actual |')
    ..writeln('| --- | --- | --- |');
  for (final row in planVsActual) {
    buffer.writeln(
      '| ${row['date']} | ${(row['planned'] as List).join(', ')} | ${(row['actual'] as List).join(', ')} |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Warnings')
    ..writeln()
    ..writeln('| Date | Rule | Level | Evidence | Next-day readiness | Next-day fatigue |')
    ..writeln('| --- | --- | --- | --- | --- | --- |');
  for (final warning in snapshot.warnings) {
    final next = _nextDay(warning.date);
    buffer.writeln(
      '| ${warning.date} | ${warning.rule} | ${warning.level} | ${warning.evidence} | ${snapshot.readinessByDay[next] ?? ''} | ${snapshot.fatigueByDay[next] ?? ''} |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Patterns')
    ..writeln()
    ..writeln('| Key | N | Mean readiness | Mean fatigue |')
    ..writeln('| --- | --- | --- | --- |');
  for (final pattern in snapshot.patterns) {
    buffer.writeln(
      '| ${pattern.key} | ${pattern.n} | ${pattern.meanNextReadiness.toStringAsFixed(1)} | ${pattern.meanNextFatigue.toStringAsFixed(1)} |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Next week')
    ..writeln()
    ..writeln('| Lift | Card |')
    ..writeln('| --- | --- |');
  for (final suggestion in snapshot.suggestions) {
    buffer.writeln('| ${suggestion.exerciseName} | ${suggestion.card} |');
  }
  buffer
    ..writeln()
    ..writeln('## Schema')
    ..writeln()
    ..writeln('`fitness-summary-v1`')
    ..writeln()
    ..writeln(
      'Sessions have `type` (`gym`, `muay_thai`, `run`, `hike`, `yoga`, `other`), `duration_min`, `rpe`, `sets` (`weight_kg`, `reps`, `set_count`) and `blocks` for Muay Thai (`subtype`, `duration_min`, `rpe`, `load`). Load on a block is duration in minutes times RPE.',
    )
    ..writeln()
    ..writeln(
      'Check-ins have `slot` `morning` (soreness, energy, sleep quality, sleep hours, mood, stress) or `evening` (session feel, ate well, stress, energy). Readiness uses both.',
    )
    ..writeln()
    ..writeln(
      'Warnings include the rule, whether it was shown, the evidence, and the next-day readiness and fatigue when a check-in exists.',
    )
    ..writeln()
    ..writeln(
      'Patterns are rolling means over the last 8 occurrences. `n` is the size of that window.',
    )
    ..writeln()
    ..writeln(
      'Overload suggestions are the rule-based next-week cards. `action` is `progress`, `keep`, `hold`, or `deload`. Weights are kilograms.',
    );
  return buffer.toString();
}
