import 'package:fitness_tracker/models/training.dart';
import 'package:fitness_tracker/services/goals.dart';
import 'package:fitness_tracker/services/voice_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  test('a strength goal stores 3-6 and still judges 6s against 8-12', () async {
    final store = await openStore(now: DateTime(2026, 10, 12, 9));
    final bench = store.exerciseByName('Bench press')!;
    await store.saveParse(
      ParseResult(
        normalised: 'bench',
        plans: const [],
        sessions: [
          ParsedSession(
            type: 'gym',
            rpe: 6,
            raw: 'bench',
            sets: [
              ParsedSet(
                exerciseId: bench.id,
                exerciseName: bench.name,
                sets: 2,
                reps: 6,
                weightKg: 80,
                muscleGroups: bench.muscleGroups,
              ),
            ],
          ),
        ],
      ),
      on: DateTime(2026, 10, 5),
    );

    await store.loadWeek(DateTime(2026, 10, 12));
    final before = await store.suggestionsForWeek('2026-10-05');
    expect(before.single.card, 'Bench: 80 kg x 6,6 -> keep 80, aim 8s');

    await store.addGoal(kind: GoalKind.general, general: 'strength');
    await store.loadWeek(DateTime(2026, 10, 12));
    final after = await store.suggestionsForWeek('2026-10-05');
    expect(after.single.repLow, 3);
    expect(after.single.repHigh, 6);
    expect(after.single.card, 'Bench: 80 kg x 6,6 -> keep 80, aim 3s');

    final week = await store.loadWeek(DateTime(2026, 10, 12));
    expect(week.goalLines, contains('Strength · 0/0 sets in 3-6'));
  });

  test(
    'a saved run is flagged against the pace goal in the day export',
    () async {
      final store = await openStore(now: DateTime(2026, 10, 12, 9));
      await store.addGoal(kind: GoalKind.pace, distanceKm: 5, targetPaceS: 300);
      await store.saveParse(
        ParseResult(
          normalised: 'ran 5k',
          plans: const [],
          sessions: [
            ParsedSession(
              type: 'run',
              durationMin: 28,
              rpe: 6,
              distanceKm: 5,
              raw: 'ran 5k',
            ),
          ],
        ),
        on: DateTime(2026, 10, 12),
      );

      final day = await store.loadDay(DateTime(2026, 10, 12));
      expect(paceFlagLines(day.sessions.single, store.goals), [
        'slow: 5:36/km at 5 km, goal 5:00/km',
      ]);

      final files = await store.exportRange(
        start: DateTime(2026, 10, 12),
        end: DateTime(2026, 10, 12),
        kind: 'day',
      );
      expect(files.plain, contains('Run · 5 km · 28:00 · 5:36/km'));
      expect(files.plain, contains('slow: 5:36/km at 5 km, goal 5:00/km'));
      expect(files.plain, contains('5 km · 5:36/km · goal 5:00/km · slow'));
      expect(files.plain, isNot(contains('## Balance')));

      final workout = await store.exportSession(day.sessions.single);
      expect(workout.plain, contains('Workout · Mon 12 Oct'));
      expect(workout.plain, contains('slow: 5:36/km at 5 km, goal 5:00/km'));
    },
  );
}
