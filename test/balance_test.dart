import 'dart:io';

import 'package:fitness_tracker/models/training.dart';
import 'package:fitness_tracker/services/balance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SetRow lift({
    required String name,
    required List<String> muscles,
    required int sets,
    required int reps,
    required double kg,
  }) {
    return SetRow(
      exerciseName: name,
      muscleGroups: muscles,
      setCount: sets,
      reps: reps,
      weightKg: kg,
    );
  }

  BalanceReport week(List<SetRow> sets) {
    return buildBalance(
      start: DateTime(2026, 10, 5),
      end: DateTime(2026, 10, 11),
      sessions: [Session(date: '2026-10-05', type: 'gym', sets: sets)],
    );
  }

  test('thresholds are 6 sets and 60 percent', () {
    expect(balanceHeavyMinSets, 6);
    expect(balanceLightMaxPercent, 60);
  });

  test('legs at 30 percent of chest is upper-heavy', () {
    final report = week([
      lift(
        name: 'Bench press',
        muscles: const ['chest', 'shoulders', 'triceps'],
        sets: 10,
        reps: 8,
        kg: 70,
      ),
      lift(
        name: 'Back squat',
        muscles: const ['legs', 'quads', 'glutes'],
        sets: 3,
        reps: 5,
        kg: 100,
      ),
    ]);
    expect(
      report.flags,
      contains('upper-heavy: legs got 30% of the sets chest got'),
    );
    final chest = report.muscles.firstWhere(
      (muscle) => muscle.muscle == 'chest',
    );
    expect(chest.sets, 10);
    expect(chest.volumeKg, 5600);
    final legs = report.muscles.firstWhere((muscle) => muscle.muscle == 'legs');
    expect(legs.sets, 3);
    expect(legs.volumeKg, 1500);
  });

  test('60 percent flags and 61 percent does not', () {
    final atLimit = week([
      lift(
        name: 'Bench press',
        muscles: const ['chest'],
        sets: 10,
        reps: 8,
        kg: 60,
      ),
      lift(
        name: 'Back squat',
        muscles: const ['legs'],
        sets: 6,
        reps: 5,
        kg: 100,
      ),
    ]);
    expect(
      atLimit.flags,
      contains('upper-heavy: legs got 60% of the sets chest got'),
    );

    final under = week([
      lift(
        name: 'Bench press',
        muscles: const ['chest'],
        sets: 10,
        reps: 8,
        kg: 60,
      ),
      lift(
        name: 'Back squat',
        muscles: const ['legs'],
        sets: 7,
        reps: 5,
        kg: 100,
      ),
    ]);
    expect(under.flags.where((flag) => flag.startsWith('upper-')), isEmpty);
  });

  test('five sets on the heavy side is not enough to flag', () {
    final report = week([
      lift(
        name: 'Bench press',
        muscles: const ['chest'],
        sets: 5,
        reps: 8,
        kg: 60,
      ),
    ]);
    expect(report.flags, isEmpty);
    expect(report.muscles.single.sets, 5);
  });

  test('a missing side is named and counted as zero', () {
    final report = week([
      lift(
        name: 'Bench press',
        muscles: const ['chest'],
        sets: 8,
        reps: 5,
        kg: 60,
      ),
    ]);
    expect(
      report.flags,
      contains('upper-heavy: legs got 0% of the sets chest got'),
    );
    expect(
      report.flags,
      contains('push-heavy: pull got 0% of the sets chest got'),
    );
  });

  test('push and pull flag from the busiest muscle on each side', () {
    final report = week([
      lift(
        name: 'Bench press',
        muscles: const ['chest'],
        sets: 10,
        reps: 5,
        kg: 60,
      ),
      lift(
        name: 'Barbell row',
        muscles: const ['back', 'biceps'],
        sets: 4,
        reps: 8,
        kg: 40,
      ),
    ]);
    expect(
      report.flags,
      contains('push-heavy: back got 40% of the sets chest got'),
    );
  });

  test('front and back chain use quads against hamstrings', () {
    final report = week([
      lift(
        name: 'Leg extension',
        muscles: const ['quads'],
        sets: 10,
        reps: 12,
        kg: 40,
      ),
      lift(
        name: 'Leg curl',
        muscles: const ['hamstrings'],
        sets: 3,
        reps: 10,
        kg: 30,
      ),
    ]);
    expect(
      report.flags,
      contains('front-heavy: hamstrings got 30% of the sets quads got'),
    );
  });

  test('equal sides and runs are not flagged', () {
    final report = week([
      lift(
        name: 'Bench press',
        muscles: const ['chest'],
        sets: 8,
        reps: 8,
        kg: 60,
      ),
      lift(
        name: 'Barbell row',
        muscles: const ['back'],
        sets: 8,
        reps: 8,
        kg: 50,
      ),
      const SetRow(
        exerciseName: 'Run',
        muscleGroups: ['legs'],
        distanceKm: 5,
        durationS: 1680,
      ),
    ]);
    expect(report.flags.where((flag) => flag.startsWith('push-')), isEmpty);
    expect(report.muscles.where((muscle) => muscle.muscle == 'legs'), isEmpty);
  });

  test('one and six sets rounds the percentage up', () {
    final report = week([
      lift(
        name: 'Bench press',
        muscles: const ['chest'],
        sets: 6,
        reps: 5,
        kg: 40,
      ),
      lift(
        name: 'Barbell row',
        muscles: const ['back'],
        sets: 1,
        reps: 8,
        kg: 40,
      ),
    ]);
    expect(
      report.flags,
      contains('push-heavy: back got 17% of the sets chest got'),
    );
  });

  test('a month week includes Sunday and the next week starts on Monday', () {
    final reports = balanceReports(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 31),
      splitWeeks: true,
      sessions: [
        Session(
          date: '2026-10-04',
          type: 'gym',
          sets: [
            lift(
              name: 'Bench press',
              muscles: const ['chest'],
              sets: 4,
              reps: 8,
              kg: 70,
            ),
          ],
        ),
        Session(
          date: '2026-10-05',
          type: 'gym',
          sets: [
            lift(
              name: 'Barbell row',
              muscles: const ['back'],
              sets: 4,
              reps: 8,
              kg: 50,
            ),
          ],
        ),
      ],
    );
    expect(reports[0].end, DateTime(2026, 10, 4));
    expect(reports[0].end.weekday, DateTime.sunday);
    expect(reports[0].muscles.single.muscle, 'chest');
    expect(reports[1].start, DateTime(2026, 10, 5));
    expect(reports[1].start.weekday, DateTime.monday);
    expect(reports[1].end, DateTime(2026, 10, 11));
    expect(reports[1].end.weekday, DateTime.sunday);
    expect(reports[1].muscles.single.muscle, 'back');
  });

  test('full is ignored and the other muscles on the set still count', () {
    final onlyFull = week([
      const SetRow(
        exerciseName: 'Burpee',
        muscleGroups: ['full'],
        setCount: 6,
        reps: 10,
        weightKg: 0,
      ),
    ]);
    expect(onlyFull.muscles, isEmpty);

    final mixed = week([
      const SetRow(
        exerciseName: 'Burpee',
        muscleGroups: ['full', 'chest'],
        setCount: 4,
        reps: 10,
        weightKg: 20,
      ),
    ]);
    expect(mixed.muscles.where((muscle) => muscle.muscle == 'full'), isEmpty);
    expect(mixed.muscles.single.muscle, 'chest');
    expect(mixed.muscles.single.sets, 4);
    expect(mixed.muscles.single.volumeKg, 800);
  });

  test(
    'the Monday after the clocks go back stays in the month balance',
    () async {
      final dart = _dartBin();
      final result = await Process.run(
        dart,
        ['run', 'test/support/dst_month_balance.dart'],
        environment: {...Platform.environment, 'TZ': 'Europe/London'},
        workingDirectory: Directory.current.path,
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );
}

String _dartBin() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    return '$root/bin/dart';
  }
  final home = Platform.environment['HOME'] ?? '';
  return '$home/flutter/bin/dart';
}
