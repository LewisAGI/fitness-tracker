import 'load_model.dart';
import 'normalise.dart';

enum OverloadAction { progress, keep, hold, deload }

class WorkingSet {
  const WorkingSet({required this.weightKg, required this.reps});

  final double weightKg;
  final int reps;
}

class LiftWeekInput {
  const LiftWeekInput({
    required this.exerciseName,
    required this.muscleGroups,
    required this.sets,
    this.priorRepLow,
    this.priorRepHigh,
    this.exerciseId = 0,
  });

  final int exerciseId;
  final String exerciseName;
  final List<String> muscleGroups;
  final List<WorkingSet> sets;
  final int? priorRepLow;
  final int? priorRepHigh;
}

class WeekContext {
  const WeekContext({this.meanReadiness, this.warnedMuscles = const {}});

  final double? meanReadiness;
  final Set<String> warnedMuscles;
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
  final target = _target(lift, reps);
  final hitTop = working.every((set) => set.reps >= target.high);
  final lower = isLowerBody(lift.muscleGroups);
  final increment = lower ? 5.0 : 2.5;
  final lowReady =
      context.meanReadiness != null && context.meanReadiness! < 40;
  final warned = lift.muscleGroups.any(
    (muscle) => context.warnedMuscles.contains(muscle.toLowerCase()),
  );
  final aim = working.any((set) => set.reps < target.low)
      ? target.low
      : target.high;

  late final OverloadAction action;
  late final double nextWeight;
  int? aimReps;
  if (lowReady && warned) {
    action = OverloadAction.deload;
    nextWeight = _roundPlate(workingWeight * 0.9);
  } else if (lowReady || warned) {
    action = OverloadAction.hold;
    nextWeight = workingWeight;
  } else if (hitTop) {
    action = OverloadAction.progress;
    nextWeight = workingWeight + increment;
    aimReps = target.low;
  } else {
    action = OverloadAction.keep;
    nextWeight = workingWeight;
    aimReps = aim;
  }

  return OverloadSuggestion(
    exerciseId: lift.exerciseId,
    exerciseName: lift.exerciseName,
    muscleGroups: lift.muscleGroups,
    workingWeightKg: workingWeight,
    reps: reps,
    repLow: target.low,
    repHigh: target.high,
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

({int low, int high}) _target(LiftWeekInput lift, List<int> reps) {
  if (lift.priorRepLow != null && lift.priorRepHigh != null) {
    return (low: lift.priorRepLow!, high: lift.priorRepHigh!);
  }
  return (low: 8, high: 12);
}

double _roundPlate(double value) => (value / 2.5).round() * 2.5;

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
