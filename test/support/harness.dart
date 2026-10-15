import 'dart:io';

import 'package:fitness_tracker/data/store.dart';
import 'package:fitness_tracker/models/training.dart';
import 'package:fitness_tracker/services/dates.dart';
import 'package:fitness_tracker/services/voice_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Store> openStore({DateTime? now}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final directory = await Directory.systemTemp.createTemp('fitness_tracker');
  final store = Store(clock: () => now ?? DateTime(2026, 10, 12, 9));
  await store.init(path: '${directory.path}/fitness.db');
  return store;
}

Future<void> seedDemo(Store store) async {
  final bench = store.exerciseByName('Bench press')!;
  final squat = store.exerciseByName('Back squat')!;
  final row = store.exerciseByName('Barbell row')!;

  Future<void> thai(DateTime day) {
    return store.saveParse(
      ParseResult(
        normalised: 'muay thai',
        plans: const [],
        sessions: [
          ParsedSession(
            type: 'muay_thai',
            durationMin: 60,
            rpe: 8,
            raw: 'muay thai',
          ),
        ],
      ),
      on: day,
    );
  }

  Future<void> lift({
    required DateTime day,
    required Exercise exercise,
    required int sets,
    required int reps,
    required double weight,
    required int rpe,
  }) {
    return store.saveParse(
      ParseResult(
        normalised: exercise.name,
        plans: const [],
        sessions: [
          ParsedSession(
            type: 'gym',
            rpe: rpe,
            raw: exercise.name,
            sets: [
              ParsedSet(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                sets: sets,
                reps: reps,
                weightKg: weight,
                muscleGroups: exercise.muscleGroups,
              ),
            ],
          ),
        ],
      ),
      on: day,
    );
  }

  Future<void> morning(
    DateTime day, {
    required int soreness,
    required int energy,
  }) {
    return store.saveCheckIn(
      CheckIn(
        date: isoDate(day),
        slot: 'morning',
        soreness: soreness,
        energy: energy,
        sleepQuality: 10,
        sleepHours: 8,
        mood: 10,
        stress: 1,
      ),
    );
  }

  await thai(DateTime(2026, 9, 15));
  await lift(
    day: DateTime(2026, 9, 16),
    exercise: squat,
    sets: 4,
    reps: 5,
    weight: 100,
    rpe: 8,
  );
  await morning(DateTime(2026, 9, 17), soreness: 8, energy: 3);

  await thai(DateTime(2026, 9, 22));
  await lift(
    day: DateTime(2026, 9, 23),
    exercise: squat,
    sets: 4,
    reps: 5,
    weight: 100,
    rpe: 8,
  );
  await morning(DateTime(2026, 9, 24), soreness: 7, energy: 4);

  await thai(DateTime(2026, 9, 29));
  await lift(
    day: DateTime(2026, 9, 30),
    exercise: squat,
    sets: 4,
    reps: 5,
    weight: 100,
    rpe: 8,
  );
  await morning(DateTime(2026, 10, 1), soreness: 9, energy: 2);

  await lift(
    day: DateTime(2026, 10, 5),
    exercise: bench,
    sets: 2,
    reps: 7,
    weight: 80,
    rpe: 6,
  );
  await lift(
    day: DateTime(2026, 10, 6),
    exercise: row,
    sets: 2,
    reps: 12,
    weight: 50,
    rpe: 8,
  );
  await thai(DateTime(2026, 10, 11));
  await lift(
    day: DateTime(2026, 10, 12),
    exercise: bench,
    sets: 4,
    reps: 8,
    weight: 70,
    rpe: 6,
  );
  await store.addPlan(
    date: DateTime(2026, 10, 12),
    type: 'gym',
    muscleGroups: const ['legs'],
    intensity: 'hard',
  );
  await morning(DateTime(2026, 10, 12), soreness: 2, energy: 8);
}
