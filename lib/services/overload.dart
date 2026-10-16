import 'load_model.dart';
import 'normalise.dart';

enum OverloadAction { progress, keep, hold, deload }

/// How an active general goal changes the rep range and the load step.
/// [standard] is the default overload rule.
enum TrainingBias { standard, strength, fitness, hypertrophy }

TrainingBias biasFromGeneral(String? general) => switch (general) {
  'strength' => TrainingBias.strength,
  'fitness' => TrainingBias.fitness,
  'hypertrophy' => TrainingBias.hypertrophy,
  _ => TrainingBias.standard,
};

({int low, int high}) rangeForBias(TrainingBias bias) => switch (bias) {
  TrainingBias.strength => (low: 3, high: 6),
  TrainingBias.hypertrophy => (low: 6, high: 12),
  _ => (low: 8, high: 12),
};

double stepKg(TrainingBias bias, {required bool lower}) {
  if (bias == TrainingBias.strength) {
    return lower ? 10 : 5;
  }
  return lower ? 5 : 2.5;
}

class WorkingSet {
  const WorkingSet({required this.weightKg, required this.reps, this.rir});

  final double weightKg;
  final int reps;
  final int? rir;
}

class LiftWeekInput {
  const LiftWeekInput({
    required this.exerciseName,
    required this.muscleGroups,
    required this.sets,
    this.priorRepLow,
    this.priorRepHigh,
    this.exerciseId = 0,
    this.bias,
  });

  final int exerciseId;
  final String exerciseName;
  final List<String> muscleGroups;
  final List<WorkingSet> sets;
  final int? priorRepLow;
  final int? priorRepHigh;

  /// Replaces the week bias for this lift when set.
  final TrainingBias? bias;
}

class WeekContext {
  const WeekContext({
    this.meanReadiness,
    this.warnedMuscles = const {},
    this.bias = TrainingBias.standard,
  });

  final double? meanReadiness;
  final Set<String> warnedMuscles;
  final TrainingBias bias;
}

class OverloadSuggestion {
  const OverloadSuggestion({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroups,
    required this.workingWeightKg,
    required this.reps,
    required this.repLow,
    required this.repHigh,
    required this.action,
    required this.suggestedWeightKg,
    required this.card,
    this.aimReps,
  });

  final int exerciseId;
  final String exerciseName;
  final List<String> muscleGroups;
  final double workingWeightKg;
  final List<int> reps;
  final int repLow;
  final int repHigh;
  final OverloadAction action;
  final double suggestedWeightKg;
  final int? aimReps;
  final String card;
}

List<OverloadSuggestion> suggestWeek({
  required List<LiftWeekInput> lifts,
  required WeekContext context,
}) {
  final suggestions = <OverloadSuggestion>[];
  for (final lift in lifts) {
    final suggestion = suggestLift(lift, context);
    if (suggestion != null) {
      suggestions.add(suggestion);
    }
  }
  return suggestions;
}

OverloadSuggestion? suggestLift(LiftWeekInput lift, WeekContext context) {
  final weighted = lift.sets.where((set) => set.weightKg > 0).toList();
  if (weighted.isEmpty) {
    return null;
  }
  final workingWeight = weighted
      .map((set) => set.weightKg)
      .reduce((a, b) => a > b ? a : b);
  final working = weighted
      .where((set) => (set.weightKg - workingWeight).abs() < 0.05)
      .toList();
  final reps = working.map((set) => set.reps).toList();
  final bias = lift.bias ?? context.bias;
  // Hit and miss use the range this week was trained for. The goal only
  // chooses the range stored for next week, and the size of the step.
  final judged = _previousRange(lift);
  final next = bias == TrainingBias.standard ? judged : rangeForBias(bias);
  final hitTop = working.every((set) => set.reps >= judged.high);
  final lower = isLowerBody(lift.muscleGroups);
  final increment = stepKg(bias, lower: lower);
  final lowReady = context.meanReadiness != null && context.meanReadiness! < 40;
  final warned = lift.muscleGroups.any(
    (muscle) => context.warnedMuscles.contains(muscle.toLowerCase()),
  );
  final missed = working.any((set) => set.reps < judged.low);
  final aim = missed ? next.low : next.high;
  final flagged = lowReady || warned;
  final failedEarly = working.any(
    (set) => set.rir == 0 && set.reps < judged.low,
  );
  // RIR above 5 is rejected input and must not step the weight up.
  final rirStep = working.every(
    (set) =>
        set.rir != null &&
        set.rir! >= 2 &&
        set.rir! <= 5 &&
        set.reps >= judged.low,
  );

  late final OverloadAction action;
  late double nextWeight;
  int? aimReps;
  // A flag outranks a step-up. Deload only when reps were missed as well.
  // Low readiness and a strain warning together still hold when the reps were hit.
  if (missed && flagged) {
    action = OverloadAction.deload;
    nextWeight = workingWeight * 0.9;
  } else if (failedEarly || flagged) {
    action = OverloadAction.hold;
    nextWeight = workingWeight;
  } else if (hitTop || rirStep) {
    action = OverloadAction.progress;
    nextWeight = workingWeight + increment;
    aimReps = next.low;
  } else {
    action = OverloadAction.keep;
    nextWeight = workingWeight;
    aimReps = aim;
  }
  nextWeight = _roundPlate(nextWeight);

  return OverloadSuggestion(
    exerciseId: lift.exerciseId,
    exerciseName: lift.exerciseName,
    muscleGroups: lift.muscleGroups,
    workingWeightKg: workingWeight,
    reps: reps,
    repLow: next.low,
    repHigh: next.high,
    action: action,
    suggestedWeightKg: nextWeight,
    aimReps: aimReps,
    card: _card(
      name: shortLift(lift.exerciseName),
      weight: workingWeight,
      reps: reps,
      action: action,
      next: nextWeight,
      aim: aimReps,
    ),
  );
}

/// The range the lifter was already working in. A general goal does not replace it.
({int low, int high}) _previousRange(LiftWeekInput lift) {
  if (lift.priorRepLow != null && lift.priorRepHigh != null) {
    return (low: lift.priorRepLow!, high: lift.priorRepHigh!);
  }
  return rangeForBias(TrainingBias.standard);
}

/// Nearest 2.5 kg, applied to the final suggestion. An exact halfway step rounds down.
double _roundPlate(double value) {
  final milli = (value * 1000).round();
  const step = 2500;
  final base = milli ~/ step;
  final remainder = milli - base * step;
  final picked = remainder > 1250 ? base + 1 : base;
  return picked * 2.5;
}

String shortLift(String name) {
  const known = {
    'bench press': 'Bench',
    'incline bench press': 'Incline bench',
    'close-grip bench press': 'Close-grip bench',
    'back squat': 'Squat',
    'front squat': 'Front squat',
    'barbell row': 'Row',
    'overhead press': 'Overhead press',
    'deadlift': 'Deadlift',
    'romanian deadlift': 'RDL',
  };
  return known[name.toLowerCase()] ?? name;
}

String _card({
  required String name,
  required double weight,
  required List<int> reps,
  required OverloadAction action,
  required double next,
  required int? aim,
}) {
  final head = '$name: ${fmtKg(weight)} kg x ${reps.join(',')} -> ';
  return switch (action) {
    OverloadAction.progress => '$head${fmtKg(next)} kg',
    OverloadAction.keep => '${head}keep ${fmtKg(weight)}, aim ${aim}s',
    OverloadAction.hold => '${head}hold ${fmtKg(weight)}',
    OverloadAction.deload => '${head}deload ${fmtKg(next)} kg',
  };
}
