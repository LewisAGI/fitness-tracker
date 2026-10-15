import 'package:fitness_tracker/services/overload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LiftWeekInput bench(List<int> reps, {int? low, int? high, double weight = 80}) {
    return LiftWeekInput(
      exerciseName: 'Bench press',
      muscleGroups: const ['chest', 'shoulders', 'triceps'],
      sets: [for (final rep in reps) WorkingSet(weightKg: weight, reps: rep)],
      priorRepLow: low,
      priorRepHigh: high,
    );
  }

  LiftWeekInput squat(List<int> reps, {double weight = 100}) {
    return LiftWeekInput(
      exerciseName: 'Back squat',
      muscleGroups: const ['legs', 'quads', 'glutes'],
      sets: [for (final rep in reps) WorkingSet(weightKg: weight, reps: rep)],
    );
  }

  const clear = WeekContext();

  test('every set at the top of 8-12 adds 2.5 kg on an upper-body lift', () {
    final suggestion = suggestLift(bench([12, 12]), clear)!;
    expect(suggestion.action, OverloadAction.progress);
    expect(suggestion.card, 'Bench: 80 kg x 12,12 -> 82.5 kg');
  });

  test('every set at the top of 8-12 adds 5 kg on a lower-body lift', () {
    final suggestion = suggestLift(squat([12, 12]), clear)!;
    expect(suggestion.action, OverloadAction.progress);
    expect(suggestion.card, 'Squat: 100 kg x 12,12 -> 105 kg');
  });

  test('missing the bottom of the range keeps the weight and aims at 8s', () {
    final suggestion = suggestLift(bench([7, 7]), clear)!;
    expect(suggestion.action, OverloadAction.keep);
    expect(suggestion.card, 'Bench: 80 kg x 7,7 -> keep 80, aim 8s');
  });

  test('reps inside the range but short of the top aim at 12s', () {
    final suggestion = suggestLift(bench([10, 9]), clear)!;
    expect(suggestion.action, OverloadAction.keep);
    expect(suggestion.card, 'Bench: 80 kg x 10,9 -> keep 80, aim 12s');
  });

  test('last week target replaces the default 8-12 range', () {
    final hit = suggestLift(bench([5, 5], low: 5, high: 5), clear)!;
    expect(hit.action, OverloadAction.progress);
    expect(hit.card, 'Bench: 80 kg x 5,5 -> 82.5 kg');
    final missed = suggestLift(bench([5, 4], low: 5, high: 5), clear)!;
    expect(missed.card, 'Bench: 80 kg x 5,4 -> keep 80, aim 5s');
  });

  test('low readiness holds instead of adding weight', () {
    final suggestion = suggestLift(
      bench([12, 12]),
      const WeekContext(meanReadiness: 39),
    )!;
    expect(suggestion.action, OverloadAction.hold);
    expect(suggestion.card, 'Bench: 80 kg x 12,12 -> hold 80');
  });

  test('readiness of 40 does not hold', () {
    final suggestion = suggestLift(
      bench([12, 12]),
      const WeekContext(meanReadiness: 40),
    )!;
    expect(suggestion.action, OverloadAction.progress);
  });

  test('a muscle-group strain warning holds the lift', () {
    final suggestion = suggestLift(
      squat([12, 12]),
      const WeekContext(warnedMuscles: {'legs'}),
    )!;
    expect(suggestion.action, OverloadAction.hold);
    expect(suggestion.card, 'Squat: 100 kg x 12,12 -> hold 100');
  });

  test('a warning for another muscle does not hold the lift', () {
    final suggestion = suggestLift(
      bench([12, 12]),
      const WeekContext(warnedMuscles: {'legs'}),
    )!;
    expect(suggestion.action, OverloadAction.progress);
  });

  test('low readiness and a strain warning hold when the reps were hit', () {
    final suggestion = suggestLift(
      bench([12, 12]),
      const WeekContext(meanReadiness: 30, warnedMuscles: {'chest'}),
    )!;
    expect(suggestion.action, OverloadAction.hold);
    expect(suggestion.card, 'Bench: 80 kg x 12,12 -> hold 80');
  });

  test('missed reps and both flags deload about 10%', () {
    final missed = suggestLift(
      bench([7, 7]),
      const WeekContext(meanReadiness: 20, warnedMuscles: {'triceps'}),
    )!;
    expect(missed.action, OverloadAction.deload);
    expect(missed.suggestedWeightKg, 72.5);
    expect(missed.card, 'Bench: 80 kg x 7,7 -> deload 72.5 kg');
  });

  test('missed reps and low readiness alone deload', () {
    final suggestion = suggestLift(
      bench([7, 7]),
      const WeekContext(meanReadiness: 30),
    )!;
    expect(suggestion.action, OverloadAction.deload);
    expect(suggestion.card, 'Bench: 80 kg x 7,7 -> deload 72.5 kg');
  });

  test('missed reps and a strain warning alone deload', () {
    final suggestion = suggestLift(
      bench([7, 7]),
      const WeekContext(warnedMuscles: {'chest'}),
    )!;
    expect(suggestion.action, OverloadAction.deload);
    expect(suggestion.suggestedWeightKg, 72.5);
  });

  test('warm-up sets below the working weight are ignored', () {
    final suggestion = suggestLift(
      LiftWeekInput(
        exerciseName: 'Bench press',
        muscleGroups: const ['chest'],
        sets: const [
          WorkingSet(weightKg: 40, reps: 12),
          WorkingSet(weightKg: 80, reps: 12),
          WorkingSet(weightKg: 80, reps: 12),
        ],
      ),
      clear,
    )!;
    expect(suggestion.card, 'Bench: 80 kg x 12,12 -> 82.5 kg');
  });

  test('bodyweight work is skipped', () {
    expect(
      suggestLift(
        const LiftWeekInput(
          exerciseName: 'Pull-up',
          muscleGroups: ['back'],
          sets: [],
        ),
        clear,
      ),
      isNull,
    );
  });

  LiftWeekInput withRir(List<(int, int?)> sets, {bool lower = false, double weight = 80}) {
    return LiftWeekInput(
      exerciseName: lower ? 'Back squat' : 'Bench press',
      muscleGroups: lower
          ? const ['legs', 'quads']
          : const ['chest', 'shoulders', 'triceps'],
      sets: [
        for (final set in sets)
          WorkingSet(weightKg: weight, reps: set.$1, rir: set.$2),
      ],
    );
  }

  test('RIR at least 2 on every set steps up inside the rep range', () {
    final suggestion = suggestLift(withRir([(10, 2), (9, 3)]), clear)!;
    expect(suggestion.action, OverloadAction.progress);
    expect(suggestion.card, 'Bench: 80 kg x 10,9 -> 82.5 kg');
    final squat = suggestLift(
      withRir([(10, 2), (10, 2)], lower: true, weight: 100),
      clear,
    )!;
    expect(squat.card, 'Squat: 100 kg x 10,10 -> 105 kg');
  });

  test('failure before the target reps holds', () {
    final suggestion = suggestLift(withRir([(6, 0), (8, 2)]), clear)!;
    expect(suggestion.action, OverloadAction.hold);
    expect(suggestion.card, 'Bench: 80 kg x 6,8 -> hold 80');
  });

  test('null RIR keeps the existing rep rules', () {
    final suggestion = suggestLift(withRir([(10, null), (9, 2)]), clear)!;
    expect(suggestion.action, OverloadAction.keep);
    expect(suggestion.card, 'Bench: 80 kg x 10,9 -> keep 80, aim 12s');
  });

  test('failure before target still deloads when readiness and a warning both apply', () {
    final suggestion = suggestLift(
      withRir([(6, 0)]),
      const WeekContext(meanReadiness: 30, warnedMuscles: {'chest'}),
    )!;
    expect(suggestion.action, OverloadAction.deload);
    expect(suggestion.card, 'Bench: 80 kg x 6 -> deload 72.5 kg');
  });

  test('RIR 2 below the bottom of the range does not step up', () {
    final suggestion = suggestLift(withRir([(7, 2), (7, 2)]), clear)!;
    expect(suggestion.action, OverloadAction.keep);
    expect(suggestion.card, 'Bench: 80 kg x 7,7 -> keep 80, aim 8s');
  });

  test('RIR 0 after the target does not hold', () {
    final atTop = suggestLift(withRir([(12, 0), (12, 0)]), clear)!;
    expect(atTop.action, OverloadAction.progress);
    expect(atTop.card, 'Bench: 80 kg x 12,12 -> 82.5 kg');
    final inside = suggestLift(withRir([(10, 0), (10, 0)]), clear)!;
    expect(inside.action, OverloadAction.keep);
    expect(inside.card, 'Bench: 80 kg x 10,10 -> keep 80, aim 12s');
  });

  test('RIR 0 before the target deloads when one flag applies', () {
    final suggestion = suggestLift(
      withRir([(6, 0)]),
      const WeekContext(meanReadiness: 30),
    )!;
    expect(suggestion.action, OverloadAction.deload);
    expect(suggestion.card, 'Bench: 80 kg x 6 -> deload 72.5 kg');
  });

  test('a flag holds a week that would otherwise step up on RIR', () {
    final suggestion = suggestLift(
      withRir([(10, 3), (10, 2)]),
      const WeekContext(warnedMuscles: {'triceps'}),
    )!;
    expect(suggestion.action, OverloadAction.hold);
  });

  test('RIR 10 inside the range does not step up', () {
    final suggestion = suggestLift(withRir([(10, 10), (10, 10)]), clear)!;
    expect(suggestion.action, OverloadAction.keep);
    expect(suggestion.card, 'Bench: 80 kg x 10,10 -> keep 80, aim 12s');
  });

  test('an increment that lands halfway rounds down', () {
    final suggestion = suggestLift(squat([12, 12], weight: 61.25), clear)!;
    expect(suggestion.action, OverloadAction.progress);
    expect(suggestion.suggestedWeightKg, 65);
  });
}
