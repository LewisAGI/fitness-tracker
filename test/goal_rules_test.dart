import 'package:fitness_tracker/models/training.dart';
import 'package:fitness_tracker/services/goals.dart';
import 'package:fitness_tracker/services/overload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const clear = WeekContext();

  LiftWeekInput bench(
    List<int> reps, {
    int? low,
    int? high,
    double weight = 80,
    TrainingBias? bias,
    List<(int, int?)>? rir,
  }) {
    return LiftWeekInput(
      exerciseName: 'Bench press',
      muscleGroups: const ['chest', 'shoulders', 'triceps'],
      sets: [
        if (rir == null)
          for (final rep in reps) WorkingSet(weightKg: weight, reps: rep)
        else
          for (final set in rir)
            WorkingSet(weightKg: weight, reps: set.$1, rir: set.$2),
      ],
      priorRepLow: low,
      priorRepHigh: high,
      bias: bias,
    );
  }

  LiftWeekInput squat(
    List<int> reps, {
    double weight = 100,
    TrainingBias? bias,
  }) {
    return LiftWeekInput(
      exerciseName: 'Back squat',
      muscleGroups: const ['legs', 'quads', 'glutes'],
      sets: [for (final rep in reps) WorkingSet(weightKg: weight, reps: rep)],
      bias: bias,
    );
  }

  test(
    'strength stores 3-6 and steps 5 kg only when the previous range was hit',
    () {
      final hit = suggestLift(
        bench([12, 12], bias: TrainingBias.strength),
        clear,
      )!;
      expect(hit.repLow, 3);
      expect(hit.repHigh, 6);
      expect(hit.action, OverloadAction.progress);
      expect(hit.card, 'Bench: 80 kg x 12,12 -> 85 kg');

      final storedHit = suggestLift(
        bench([6, 6], low: 6, high: 6, bias: TrainingBias.strength),
        clear,
      )!;
      expect(storedHit.action, OverloadAction.progress);
      expect(storedHit.repLow, 3);
      expect(storedHit.card, 'Bench: 80 kg x 6,6 -> 85 kg');

      final missedDefault = suggestLift(
        bench([6, 6], bias: TrainingBias.strength),
        clear,
      )!;
      expect(missedDefault.action, OverloadAction.keep);
      expect(missedDefault.repLow, 3);
      expect(missedDefault.repHigh, 6);
      expect(missedDefault.card, 'Bench: 80 kg x 6,6 -> keep 80, aim 3s');

      final inside = suggestLift(
        bench([4, 4], low: 3, high: 6, bias: TrainingBias.strength),
        clear,
      )!;
      expect(inside.action, OverloadAction.keep);
      expect(inside.card, 'Bench: 80 kg x 4,4 -> keep 80, aim 6s');

      final missed = suggestLift(
        bench([2, 2], low: 3, high: 6, bias: TrainingBias.strength),
        clear,
      )!;
      expect(missed.card, 'Bench: 80 kg x 2,2 -> keep 80, aim 3s');
    },
  );

  test('strength uses a 10 kg lower step and the same plate rounding', () {
    final squatHit = suggestLift(
      squat([12, 12], bias: TrainingBias.strength),
      clear,
    )!;
    expect(squatHit.card, 'Squat: 100 kg x 12,12 -> 110 kg');

    final tie = suggestLift(
      squat([12, 12], weight: 61.25, bias: TrainingBias.strength),
      clear,
    )!;
    expect(tie.suggestedWeightKg, 70);
  });

  test('a stored 8-12 miss stays a miss when the next range is 3-6', () {
    final suggestion = suggestLift(
      bench([6, 6], low: 8, high: 12, bias: TrainingBias.strength),
      clear,
    )!;
    expect(suggestion.action, OverloadAction.keep);
    expect(suggestion.repLow, 3);
    expect(suggestion.repHigh, 6);
    expect(suggestion.card, 'Bench: 80 kg x 6,6 -> keep 80, aim 3s');
  });

  test('fitness keeps 8-12 and the existing steps', () {
    final upper = suggestLift(
      bench([12, 12], bias: TrainingBias.fitness),
      clear,
    )!;
    expect(upper.repLow, 8);
    expect(upper.repHigh, 12);
    expect(upper.card, 'Bench: 80 kg x 12,12 -> 82.5 kg');
    final lower = suggestLift(
      squat([12, 12], bias: TrainingBias.fitness),
      clear,
    )!;
    expect(lower.card, 'Squat: 100 kg x 12,12 -> 105 kg');
  });

  test('hypertrophy uses 6-12 and the existing steps', () {
    final top = suggestLift(
      bench([12, 12], bias: TrainingBias.hypertrophy),
      clear,
    )!;
    expect(top.repLow, 6);
    expect(top.repHigh, 12);
    expect(top.card, 'Bench: 80 kg x 12,12 -> 82.5 kg');
    final inside = suggestLift(
      bench([6, 6], bias: TrainingBias.hypertrophy),
      clear,
    )!;
    expect(inside.action, OverloadAction.keep);
    expect(inside.repLow, 6);
    expect(inside.repHigh, 12);
    expect(inside.card, 'Bench: 80 kg x 6,6 -> keep 80, aim 6s');
  });

  test('the default rule is unchanged when no goal is set', () {
    final suggestion = suggestLift(bench([12, 12]), clear)!;
    expect(suggestion.card, 'Bench: 80 kg x 12,12 -> 82.5 kg');
    final stored = suggestLift(bench([5, 5], low: 5, high: 5), clear)!;
    expect(stored.card, 'Bench: 80 kg x 5,5 -> 82.5 kg');
  });

  test('a strength week still holds and deloads on the existing flags', () {
    final held = suggestLift(
      bench([12, 12], bias: TrainingBias.strength),
      const WeekContext(meanReadiness: 30),
    )!;
    expect(held.action, OverloadAction.hold);
    expect(held.card, 'Bench: 80 kg x 12,12 -> hold 80');

    final deload = suggestLift(
      bench([2, 2], bias: TrainingBias.strength),
      const WeekContext(warnedMuscles: {'chest'}),
    )!;
    expect(deload.action, OverloadAction.deload);
    expect(deload.suggestedWeightKg, 72.5);
  });

  test('RIR of 2 inside the previous range steps the strength weight', () {
    final suggestion = suggestLift(
      bench(
        const [],
        low: 4,
        high: 8,
        rir: [(4, 2), (4, 3)],
        bias: TrainingBias.strength,
      ),
      clear,
    )!;
    expect(suggestion.action, OverloadAction.progress);
    expect(suggestion.repLow, 3);
    expect(suggestion.repHigh, 6);
    expect(suggestion.card, 'Bench: 80 kg x 4,4 -> 85 kg');
  });

  test('a hit 5x5 holds on low readiness for fitness and hypertrophy', () {
    for (final bias in [TrainingBias.fitness, TrainingBias.hypertrophy]) {
      final held = suggestLift(
        bench([5, 5, 5, 5, 5], low: 5, high: 5, bias: bias),
        const WeekContext(meanReadiness: 30),
      )!;
      expect(held.action, OverloadAction.hold, reason: bias.name);
      expect(held.card, 'Bench: 80 kg x 5,5,5,5,5 -> hold 80');
      final range = rangeForBias(bias);
      expect(held.repLow, range.low);
      expect(held.repHigh, range.high);
    }
  });

  test('the same 5x5 with RIR 2 steps up for fitness and hypertrophy', () {
    for (final bias in [TrainingBias.fitness, TrainingBias.hypertrophy]) {
      final stepped = suggestLift(
        bench(
          const [],
          low: 5,
          high: 5,
          bias: bias,
          rir: [(5, 2), (5, 2), (5, 2), (5, 2), (5, 2)],
        ),
        clear,
      )!;
      expect(stepped.action, OverloadAction.progress, reason: bias.name);
      expect(stepped.suggestedWeightKg, 82.5);
      expect(stepped.card, 'Bench: 80 kg x 5,5,5,5,5 -> 82.5 kg');
      final range = rangeForBias(bias);
      expect(stepped.repLow, range.low);
      expect(stepped.repHigh, range.high);
    }
  });

  test('strength 5, 5, 4, 4, 3 at RIR 0 and low readiness deloads', () {
    final deload = suggestLift(
      bench(
        const [],
        low: 8,
        high: 12,
        bias: TrainingBias.strength,
        rir: [(5, 0), (5, 0), (4, 0), (4, 0), (3, 0)],
      ),
      const WeekContext(meanReadiness: 30),
    )!;
    expect(deload.action, OverloadAction.deload);
    expect(deload.suggestedWeightKg, 72.5);
    expect(deload.repLow, 3);
    expect(deload.repHigh, 6);
    expect(deload.card, 'Bench: 80 kg x 5,5,4,4,3 -> deload 72.5 kg');
  });

  test('the newest general goal is the one that shapes suggestions', () {
    expect(
      shapingBias(const [
        Goal(
          id: 1,
          kind: GoalKind.general,
          general: 'fitness',
          createdOn: '2026-10-01',
        ),
        Goal(
          id: 2,
          kind: GoalKind.pace,
          distanceKm: 5,
          targetPaceS: 300,
          createdOn: '2026-10-02',
        ),
        Goal(
          id: 3,
          kind: GoalKind.general,
          general: 'strength',
          createdOn: '2026-10-03',
        ),
      ]),
      TrainingBias.strength,
    );
    expect(shapingBias(const []), TrainingBias.standard);
  });

  test(
    'a slower run at the goal distance is flagged and a faster one is met',
    () {
      const slowGoal = Goal(
        id: 1,
        kind: GoalKind.pace,
        distanceKm: 5,
        targetPaceS: 300,
        createdOn: '2026-10-01',
      );
      final slow = Session(
        date: '2026-10-06',
        type: 'run',
        rpe: 6,
        sets: const [
          SetRow(exerciseName: 'Run', distanceKm: 5, durationS: 28 * 60),
        ],
      );
      expect(paceFlagLines(slow, const [slowGoal]), [
        'slow: 5:36/km at 5 km, goal 5:00/km',
      ]);
      expect(
        goalProgressLines(const [slowGoal], [slow]).single,
        '5 km · 5:36/km · goal 5:00/km · slow',
      );

      final fast = Session(
        date: '2026-10-07',
        type: 'run',
        sets: const [
          SetRow(exerciseName: 'Run', distanceKm: 5, durationS: 24 * 60),
        ],
      );
      expect(paceFlagLines(fast, const [slowGoal]), isEmpty);
      expect(
        goalProgressLines(const [slowGoal], [fast]).single,
        '5 km · 4:48/km · goal 5:00/km · met',
      );

      final near = Session(
        date: '2026-10-08',
        type: 'run',
        sets: const [
          SetRow(exerciseName: 'Run', distanceKm: 5.04, durationS: 28 * 60),
        ],
      );
      expect(paceFlagLines(near, const [slowGoal]), isNotEmpty);
      final otherDistance = Session(
        date: '2026-10-09',
        type: 'run',
        sets: const [
          SetRow(exerciseName: 'Run', distanceKm: 5.06, durationS: 28 * 60),
        ],
      );
      expect(paceFlagLines(otherDistance, const [slowGoal]), isEmpty);
    },
  );

  test('goal lines count sets in range and the best lift', () {
    const goals = [
      Goal(
        id: 2,
        kind: GoalKind.lift,
        exerciseId: 1,
        exerciseName: 'Bench press',
        targetKg: 100,
        createdOn: '2026-10-01',
      ),
      Goal(
        id: 1,
        kind: GoalKind.general,
        general: 'strength',
        createdOn: '2026-10-01',
      ),
    ];
    final session = Session(
      date: '2026-10-05',
      type: 'gym',
      sets: const [
        SetRow(
          exerciseId: 1,
          exerciseName: 'Bench press',
          setCount: 4,
          reps: 8,
          weightKg: 70,
        ),
        SetRow(
          exerciseId: 1,
          exerciseName: 'Bench press',
          setCount: 2,
          reps: 4,
          weightKg: 80,
        ),
        SetRow(
          exerciseId: 4,
          exerciseName: 'Back squat',
          setCount: 3,
          reps: 5,
          weightKg: 100,
        ),
      ],
    );
    expect(goalProgressLines(goals, [session]), [
      'Strength · 5/9 sets in 3-6',
      'Bench press · 80 / 100 kg',
    ]);
  });

  test('pace text accepts a clock or decimal minutes', () {
    expect(parsePaceMinPerKm('5:00'), 300);
    expect(parsePaceMinPerKm('5:30'), 330);
    expect(parsePaceMinPerKm('5.5'), 330);
    expect(parsePaceMinPerKm('5:60'), isNull);
  });
}
