import 'package:fitness_tracker/models/training.dart';
import 'package:fitness_tracker/services/balance.dart';
import 'package:fitness_tracker/services/week_chart.dart';
import 'package:fitness_tracker/theme/app_theme.dart';
import 'package:fitness_tracker/widgets/balance_card.dart';
import 'package:fitness_tracker/widgets/goal_ruler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  test('load percent rounds and overreach is 1.3 times target', () {
    final series = seriesFrom(
      title: 'This week',
      points: const [186],
      labels: const ['W'],
      priorTotals: const [150],
    );
    expect(series.percent, 124);
    expect(series.target, 150);
    expect(series.overreach, closeTo(195, 0.001));
  });

  test('no earlier load makes the target the current total', () {
    final series = seriesFrom(
      title: 'This week',
      points: const [40, 0],
      labels: const ['M', 'T'],
      priorTotals: const [0, 0],
    );
    expect(series.percent, 100);
    expect(series.target, 40);
    expect(series.total, 40);
  });

  test('an empty week with no history is zero percent', () {
    final series = seriesFrom(
      title: 'This week',
      points: const [0, 0],
      labels: const ['M', 'T'],
      priorTotals: const [],
    );
    expect(series.percent, 0);
    expect(series.target, 0);
    expect(series.overreach, 0);
  });

  test('only the latest four earlier periods count', () {
    final series = seriesFrom(
      title: 'This week',
      points: const [50],
      labels: const ['W'],
      priorTotals: const [10, 20, 30, 40, 50],
    );
    expect(series.target, 35);
    expect(series.percent, (100 * 50 / 35).round());
  });

  test('neglected regions are the ones below the busiest', () {
    final report = buildBalance(
      start: DateTime(2026, 10, 12),
      end: DateTime(2026, 10, 18),
      sessions: [
        Session(
          date: '2026-10-12',
          type: 'gym',
          sets: [
            SetRow(
              exerciseName: 'Bench press',
              muscleGroups: const ['chest', 'shoulders', 'triceps'],
              setCount: 10,
              reps: 8,
              weightKg: 70,
            ),
            SetRow(
              exerciseName: 'Row',
              muscleGroups: const ['back', 'biceps'],
              setCount: 2,
              reps: 10,
              weightKg: 40,
            ),
          ],
        ),
      ],
    );
    final bars = regionBars(report);
    expect(bars.map((bar) => bar.label).toList(), ['Push', 'Pull', 'Legs', 'Core']);
    expect(bars[0].sets, 10);
    expect(bars[0].neglected, isFalse);
    expect(bars[1].sets, 2);
    expect(bars[1].neglected, isTrue);
    expect(bars[2].neglected, isTrue);
    expect(bars[3].neglected, isTrue);
  });

  test('equal regions are not marked neglected', () {
    final report = buildBalance(
      start: DateTime(2026, 10, 12),
      end: DateTime(2026, 10, 18),
      sessions: [
        Session(
          date: '2026-10-12',
          type: 'gym',
          sets: [
            SetRow(
              exerciseName: 'Bench press',
              muscleGroups: const ['chest'],
              setCount: 4,
              reps: 8,
              weightKg: 70,
            ),
            SetRow(
              exerciseName: 'Row',
              muscleGroups: const ['back'],
              setCount: 4,
              reps: 8,
              weightKg: 50,
            ),
          ],
        ),
      ],
    );
    final bars = regionBars(report);
    expect(bars[0].neglected, isFalse);
    expect(bars[1].neglected, isFalse);
    expect(bars[2].neglected, isTrue);
  });

  testWidgets('the neglected bar uses the accent', (tester) async {
    final report = buildBalance(
      start: DateTime(2026, 10, 12),
      end: DateTime(2026, 10, 18),
      sessions: [
        Session(
          date: '2026-10-12',
          type: 'gym',
          sets: [
            SetRow(
              exerciseName: 'Bench press',
              muscleGroups: const ['chest'],
              setCount: 8,
              reps: 5,
              weightKg: 80,
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: BalanceCard(report: report)),
      ),
    );
    BoxDecoration paint(String label) {
      final box = tester.widget<Container>(find.byKey(ValueKey('balance-bar-$label')));
      return box.decoration! as BoxDecoration;
    }

    expect(paint('Push').color, AppColors.ink);
    expect(paint('Pull').color, AppColors.accent);
    expect(paint('Legs').color, AppColors.accent);
    expect(paint('Core').color, AppColors.accent);
    expect(find.text('upper-heavy'), findsNothing);
  });

  testWidgets('the goal ruler snaps to a plate', (tester) async {
    double? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalRuler(value: 100, onChanged: (kg) => saved = kg),
        ),
      ),
    );
    expect(find.text('100 kg'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goal-ruler')));
    expect(saved, isNotNull);
    expect(saved! % 2.5, 0);
    expect(saved, inInclusiveRange(20, 200));
  });

  test('the demo week is a percent of earlier weeks', () async {
    final store = await openStore();
    await seedDemo(store);
    final series = await store.loadSeries(ChartPeriod.week);
    expect(series.title, 'This week');
    expect(series.points, hasLength(7));
    expect(series.points.first, greaterThan(0));
    expect(series.target, greaterThan(series.total));
    expect(series.percent, (100 * series.total / series.target).round());
    expect(series.overreach, closeTo(series.target * 1.3, 0.001));
    final week = await store.loadWeek(store.now());
    final bars = regionBars(week.balance);
    expect(bars.firstWhere((bar) => bar.label == 'Push').neglected, isFalse);
    expect(bars.firstWhere((bar) => bar.label == 'Pull').neglected, isTrue);
    expect(bars.firstWhere((bar) => bar.label == 'Legs').neglected, isTrue);
    expect(bars.firstWhere((bar) => bar.label == 'Core').neglected, isTrue);
  });
}
