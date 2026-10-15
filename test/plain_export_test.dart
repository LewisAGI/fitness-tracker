import 'package:fitness_tracker/models/training.dart';
import 'package:fitness_tracker/services/dates.dart';
import 'package:fitness_tracker/services/export_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final weekStartDay = DateTime(2026, 10, 5);
  final weekEnd = DateTime(2026, 10, 11);

  ExportSnapshot weekSnapshot() {
    return ExportSnapshot(
      kind: 'week',
      start: weekStartDay,
      end: weekEnd,
      sessions: [
        Session(
          id: 2,
          date: '2026-10-06',
          type: 'run',
          rpe: 6,
          sets: const [
            SetRow(
              exerciseName: 'Run',
              distanceKm: 5,
              durationS: 28 * 60,
            ),
          ],
        ),
        const Session(
          id: 3,
          date: '2026-10-07',
          type: 'muay_thai',
          rpe: 7,
          blocks: [
            SessionBlock(
              subtype: 'pads',
              durationMin: 20,
              rpe: 8,
              load: 160,
              label: 'Pads',
            ),
          ],
        ),
        Session(
          id: 1,
          date: '2026-10-05',
          startTime: '18:00',
          type: 'gym',
          rpe: 6,
          notes: 'left shoulder',
          sets: const [
            SetRow(
              exerciseId: 1,
              exerciseName: 'Bench press',
              setCount: 10,
              reps: 8,
              weightKg: 70,
              rir: 2,
              muscleGroups: ['chest', 'shoulders', 'triceps'],
            ),
            SetRow(
              exerciseName: 'Barbell row',
              setCount: 10,
              reps: 10,
              weightKg: 50,
              muscleGroups: ['back', 'biceps'],
            ),
            SetRow(
              exerciseName: 'Back squat',
              setCount: 3,
              reps: 5,
              weightKg: 100,
              rir: 1,
              muscleGroups: ['legs', 'quads', 'glutes'],
            ),
          ],
        ),
      ],
      plans: const [],
      checkins: const [
        CheckIn(
          date: '2026-10-05',
          slot: 'evening',
          sessionFeel: 6,
          ateWell: 8,
          stress: 3,
          energy: 5,
        ),
        CheckIn(
          date: '2026-10-05',
          slot: 'morning',
          soreness: 4,
          energy: 7,
          sleepQuality: 8,
          sleepHours: 7.5,
          mood: 6,
          stress: 3,
        ),
      ],
      warnings: const [],
      patterns: const [],
      suggestions: const [
        StoredSuggestion(
          weekStart: '2026-10-05',
          exerciseId: 1,
          exerciseName: 'Bench press',
          workingWeightKg: 70,
          repsCsv: '8',
          repLow: 3,
          repHigh: 6,
          action: 'progress',
          suggestedWeightKg: 75,
          card: 'Bench: 70 kg x 8 -> 75 kg',
        ),
      ],
      goals: const [
        Goal(
          id: 1,
          kind: GoalKind.general,
          general: 'strength',
          createdOn: '2026-10-01',
        ),
        Goal(
          id: 2,
          kind: GoalKind.lift,
          exerciseId: 1,
          exerciseName: 'Bench press',
          targetKg: 100,
          createdOn: '2026-10-01',
        ),
        Goal(
          id: 3,
          kind: GoalKind.pace,
          distanceKm: 5,
          targetPaceS: 300,
          createdOn: '2026-10-01',
        ),
      ],
    );
  }

  test('week export plain text is a stable paste block', () {
    final files = buildExport(weekSnapshot());
    final range = fmtRange(weekStartDay, weekEnd);
    expect(files.plain, '''
# Fitness Tracker
Week · $range

## 2026-10-05 18:00 · Gym · RPE 6
Bench press · 10 x 8 x 70 kg · RIR 2
Barbell row · 10 x 10 x 50 kg
Back squat · 3 x 5 x 100 kg · RIR 1
Notes: left shoulder

## 2026-10-06 · Run · RPE 6
Run · 5 km · 28:00 · 5:36/km
slow: 5:36/km at 5 km, goal 5:00/km

## 2026-10-07 · Muay Thai · RPE 7
Pads · 20 min · RPE 8

## Check-ins
2026-10-05 · Morning · soreness 4 · energy 7 · sleep 8 · hours 7.5 · mood 6 · stress 3
2026-10-05 · Evening · energy 5 · stress 3 · feel 6 · ate 8

## Balance
$range
back · 10 sets · 5000 kg
biceps · 10 sets · 5000 kg
chest · 10 sets · 5600 kg
shoulders · 10 sets · 5600 kg
triceps · 10 sets · 5600 kg
glutes · 3 sets · 1500 kg
legs · 3 sets · 1500 kg
quads · 3 sets · 1500 kg
upper-heavy: legs got 30% of the sets chest got

## Goals
Strength · 3/23 sets in 3-6
Bench press · 70 / 100 kg
5 km · 5:36/km · goal 5:00/km · slow

## Next week
Bench: 70 kg x 8 -> 75 kg
''');
    expect(files.markdown, contains('upper-heavy: legs got 30% of the sets chest got'));
    expect(files.markdown, contains('Strength · 3/23 sets in 3-6'));
    expect(files.json, contains('"flags"'));
    expect(files.json, contains('goal_progress'));
  });

  test('a workout export is one session and skips the weekly balance', () {
    final files = buildExport(
      ExportSnapshot(
        kind: 'workout',
        start: weekStartDay,
        end: weekStartDay,
        sessions: const [
          Session(
            id: 1,
            date: '2026-10-05',
            startTime: '18:00',
            type: 'gym',
            rpe: 6,
            notes: 'easy',
            sets: [
              SetRow(
                exerciseName: 'Bench press',
                setCount: 4,
                reps: 8,
                weightKg: 70,
                rir: 2,
                muscleGroups: ['chest'],
              ),
            ],
          ),
        ],
        plans: const [],
        checkins: const [
          CheckIn(
            date: '2026-10-05',
            slot: 'morning',
            soreness: 4,
            energy: 7,
          ),
        ],
        warnings: const [],
        patterns: const [],
        suggestions: const [
          StoredSuggestion(
            weekStart: '2026-10-05',
            exerciseId: 1,
            exerciseName: 'Bench press',
            workingWeightKg: 70,
            repsCsv: '8',
            repLow: 8,
            repHigh: 12,
            action: 'keep',
            suggestedWeightKg: 70,
            card: 'Bench: 70 kg x 8 -> keep 70, aim 12s',
          ),
        ],
      ),
    );
    expect(files.plain, '''
# Fitness Tracker
Workout · Mon 5 Oct

## 2026-10-05 18:00 · Gym · RPE 6
Bench press · 4 x 8 x 70 kg · RIR 2
Notes: easy

## Check-ins
2026-10-05 · Morning · soreness 4 · energy 7
''');
    expect(files.plain, isNot(contains('## Balance')));
    expect(files.plain, isNot(contains('## Next week')));
  });

  test('a month export balances each week inside the month', () {
    final files = buildExport(
      ExportSnapshot(
        kind: 'month',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 31),
        sessions: const [
          Session(
            date: '2026-10-02',
            type: 'gym',
            sets: [
              SetRow(
                exerciseName: 'Bench press',
                setCount: 8,
                reps: 5,
                weightKg: 80,
                muscleGroups: ['chest'],
              ),
            ],
          ),
          Session(
            date: '2026-10-20',
            type: 'gym',
            sets: [
              SetRow(
                exerciseName: 'Back squat',
                setCount: 8,
                reps: 5,
                weightKg: 100,
                muscleGroups: ['legs'],
              ),
            ],
          ),
        ],
        plans: const [],
        checkins: const [],
        warnings: const [],
        patterns: const [],
        suggestions: const [],
      ),
    );
    expect(files.plain, contains('Month ·'));
    expect(files.plain, contains('upper-heavy: legs got 0% of the sets chest got'));
    expect(files.plain, contains('lower-heavy: chest got 0% of the sets legs got'));
    expect(files.plain, contains(fmtRange(DateTime(2026, 10, 1), DateTime(2026, 10, 4))));
    expect(files.plain, contains(fmtRange(DateTime(2026, 10, 19), DateTime(2026, 10, 25))));
  });
}
