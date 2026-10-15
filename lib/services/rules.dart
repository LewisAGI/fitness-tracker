import 'dates.dart';
import 'load_model.dart';
import 'patterns.dart';

enum WarningLevel { standard, upgraded, muted }

class SessionFact {
  const SessionFact({
    required this.at,
    required this.type,
    required this.load,
    this.rpe,
    this.intensity,
    this.muscleGroups = const [],
    this.subtypes = const [],
  });

  final DateTime at;
  final String type;
  final double load;
  final int? rpe;
  final String? intensity;
  final List<String> muscleGroups;
  final List<String> subtypes;

  String get signature => sessionSignature(
    type: type,
    rpe: rpe,
    intensity: intensity,
    muscleGroups: muscleGroups,
    subtypes: subtypes,
  );
}

class PlanFact {
  const PlanFact({
    required this.date,
    required this.type,
    required this.load,
    this.intensity,
    this.muscleGroups = const [],
    this.durationMin,
  });

  final DateTime date;
  final String type;
  final double load;
  final String? intensity;
  final List<String> muscleGroups;
  final int? durationMin;

  String get signature => sessionSignature(
    type: type,
    intensity: intensity,
    muscleGroups: muscleGroups,
    rpe: intensity == 'hard' ? 7 : null,
  );
}

class DayWarning {
  const DayWarning({
    required this.date,
    required this.rule,
    required this.level,
    required this.evidence,
    this.muscleGroups = const [],
    this.evidenceDates = const [],
  });

  final DateTime date;
  final String rule;
  final WarningLevel level;
  final String evidence;
  final List<String> muscleGroups;
  final List<DateTime> evidenceDates;
}

class RulesInput {
  const RulesInput({
    required this.plans,
    required this.sessions,
    this.readinessByDay = const {},
    this.historicalLoads = const [],
    this.previousWeekLoads = const [],
    this.patterns = const [],
  });

  final List<PlanFact> plans;
  final List<SessionFact> sessions;
  final Map<String, double> readinessByDay;
  final List<double> historicalLoads;
  final List<double> previousWeekLoads;
  final List<PatternSample> patterns;
}

List<DayWarning> evaluateRules(RulesInput input) {
  final book = PatternBook()..samples.addAll(input.patterns);
  final warnings = <DayWarning>[];
  final days = input.plans.map((plan) => dateOnly(plan.date)).toSet().toList()
    ..sort();
  var weeklyShown = false;
  for (final day in days) {
    final dayPlans = input.plans
        .where((plan) => sameDay(plan.date, day))
        .toList();
    final yesterday = day.subtract(const Duration(days: 1));
    final yesterdaySessions = input.sessions
        .where((session) => sameDay(session.at, yesterday))
        .toList();
    final yesterdayHard = yesterdaySessions.any(
      (session) => _sessionHard(session, input.historicalLoads),
    );
    final yesterdayLegs = yesterdaySessions.any(_heavyLegs);

    final local = <DayWarning>[];
    for (final plan in dayPlans) {
      final plannedHard = _planHard(plan, input.historicalLoads);
      if (yesterdayHard && plannedHard) {
        local.add(
          DayWarning(
            date: day,
            rule: 'back_to_back_hard',
            level: WarningLevel.standard,
            evidence: 'Hard day after a hard day.',
            muscleGroups: plan.muscleGroups,
          ),
        );
      }
      final overlap = _heavyOverlap(plan, input.sessions);
      if (overlap.isNotEmpty) {
        local.add(
          DayWarning(
            date: day,
            rule: 'muscle_48h',
            level: WarningLevel.standard,
            evidence: '${_title(overlap.first)} within 48 h.',
            muscleGroups: overlap,
          ),
        );
      }
      if (yesterdayLegs && (plan.type == 'run' || plan.type == 'muay_thai')) {
        local.add(
          DayWarning(
            date: day,
            rule: 'legs_then_run_thai',
            level: WarningLevel.standard,
            evidence: plan.type == 'run' ? 'Legs then run.' : 'Legs then Thai.',
            muscleGroups: const ['legs'],
          ),
        );
      }
      final readiness = input.readinessByDay[isoDate(day)];
      if (readiness != null && readiness < 40 && plannedHard) {
        local.add(
          DayWarning(
            date: day,
            rule: 'low_readiness',
            level: WarningLevel.standard,
            evidence: 'Readiness ${readiness.round()}.',
          ),
        );
      }
    }

    if (!weeklyShown && dayPlans.isNotEmpty) {
      final ratio = acuteChronicRatio(
        thisWeek: input.plans.fold<double>(0, (sum, plan) => sum + plan.load),
        previousWeeks: input.previousWeekLoads,
      );
      if (ratio != null && ratio > 1.3) {
        weeklyShown = true;
        local.add(
          DayWarning(
            date: day,
            rule: 'weekly_load',
            level: WarningLevel.standard,
            evidence:
                'Week load ${input.plans.fold<double>(0, (sum, plan) => sum + plan.load).round()}.',
          ),
        );
      }
    }

    final plannedSig = dayPlans.isEmpty
        ? 'rest'
        : dayPlans
              .reduce(
                (a, b) => a.load >= b.load ? a : b,
              )
              .signature;
    final pairKey = yesterdaySessions.isEmpty
        ? null
        : '${daySignature([
            for (final session in yesterdaySessions)
              DaySignatureInput(
                type: session.type,
                rpe: session.rpe,
                intensity: session.intensity,
                muscleGroups: session.muscleGroups,
                subtypes: session.subtypes,
                load: session.load,
              ),
          ])}>$plannedSig';
    final single = book.stats(plannedSig);
    PatternStats? applicable;
    if (pairKey != null) {
      final pair = book.stats(pairKey);
      if (pair.n >= 3) {
        applicable = pair;
      }
    }
    applicable ??= single.n >= 3 ? single : null;
    final effect = applicable == null
        ? PatternEffect.none
        : patternEffect(applicable);

    if (effect == PatternEffect.upgrade) {
      final evidence = patternEvidence(applicable!);
      final dates = applicable.window.map((sample) => sample.outcomeDate);
      if (local.isEmpty) {
        warnings.add(
          DayWarning(
            date: day,
            rule: 'pattern',
            level: WarningLevel.upgraded,
            evidence: evidence,
            evidenceDates: dates.toList(),
            muscleGroups: dayPlans.expand((plan) => plan.muscleGroups).toSet().toList(),
          ),
        );
      } else {
        for (final warning in local) {
          warnings.add(
            DayWarning(
              date: warning.date,
              rule: warning.rule,
              level: WarningLevel.upgraded,
              evidence: evidence,
              evidenceDates: dates.toList(),
              muscleGroups: warning.muscleGroups,
            ),
          );
        }
      }
    } else if (effect == PatternEffect.downgrade) {
      for (final warning in local) {
        warnings.add(
          DayWarning(
            date: warning.date,
            rule: warning.rule,
            level: WarningLevel.muted,
            evidence: warning.evidence,
            muscleGroups: warning.muscleGroups,
          ),
        );
      }
    } else {
      warnings.addAll(local);
    }
  }
  return warnings;
}

bool _sessionHard(SessionFact session, List<double> history) {
  if (session.intensity == 'hard') {
    return true;
  }
  if (session.rpe != null && session.rpe! >= 7) {
    return true;
  }
  if (history.length >= 4 && session.load > percentile75(history)) {
    return true;
  }
  return false;
}

bool _planHard(PlanFact plan, List<double> history) {
  if (plan.intensity == 'hard') {
    return true;
  }
  if (history.length >= 4 && plan.load > percentile75(history)) {
    return true;
  }
  return false;
}

bool _heavyLegs(SessionFact session) {
  final legs = session.muscleGroups.any(
    (muscle) => legGroups.contains(muscle.toLowerCase()),
  );
  final heavy =
      (session.rpe != null && session.rpe! >= 7) || session.intensity == 'hard';
  return legs && heavy;
}

List<String> _heavyOverlap(PlanFact plan, List<SessionFact> sessions) {
  if (plan.muscleGroups.isEmpty) {
    return const [];
  }
  final found = <String>{};
  final at = DateTime(plan.date.year, plan.date.month, plan.date.day, 18);
  for (final session in sessions) {
    final gap = at.difference(session.at).inMinutes;
    if (gap <= 0 || gap > 48 * 60) {
      continue;
    }
    final heavy =
        (session.rpe != null && session.rpe! >= 7) || session.intensity == 'hard';
    if (!heavy) {
      continue;
    }
    for (final muscle in plan.muscleGroups) {
      if (session.muscleGroups.any(
        (item) => item.toLowerCase() == muscle.toLowerCase(),
      )) {
        found.add(muscle.toLowerCase());
      }
    }
  }
  return found.toList();
}

String _title(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

Set<String> warnedMuscles(List<DayWarning> warnings) {
  final muscles = <String>{};
  for (final warning in warnings) {
    if (warning.level == WarningLevel.muted) {
      continue;
    }
    if (warning.rule == 'muscle_48h' ||
        warning.rule == 'legs_then_run_thai' ||
        warning.rule == 'pattern') {
      muscles.addAll(warning.muscleGroups.map((muscle) => muscle.toLowerCase()));
    }
  }
  return muscles;
}
