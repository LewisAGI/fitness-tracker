import 'package:fitness_tracker/services/patterns.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DaySignatureInput thaiHard() => const DaySignatureInput(
    type: 'muay_thai',
    rpe: 8,
    load: 400,
  );

  DaySignatureInput legsHeavy() => const DaySignatureInput(
    type: 'gym',
    rpe: 8,
    load: 300,
    muscleGroups: ['legs', 'quads'],
  );

  test('records the pair and the last session', () {
    final book = PatternBook();
    book.learn(
      outcomeDay: DateTime(2026, 10, 3),
      dayMinus2: [thaiHard()],
      dayMinus1: [legsHeavy()],
      readiness: 40,
      fatigue: 8,
    );
    expect(book.stats('gym:legs_heavy').n, 1);
    expect(book.stats('muay_thai:hard>gym:legs_heavy').n, 1);
    expect(
      prettyPatternKey('muay_thai:hard>gym:legs_heavy'),
      'Thai hard → legs heavy',
    );
  });

  test('N below 3 does not change the default', () {
    final book = PatternBook()
      ..upsert(
        PatternSample(
          key: 'run',
          outcomeDate: DateTime(2026, 10, 1),
          readiness: 20,
          fatigue: 9,
        ),
      )
      ..upsert(
        PatternSample(
          key: 'run',
          outcomeDate: DateTime(2026, 10, 2),
          readiness: 20,
          fatigue: 9,
        ),
      );
    expect(patternEffect(book.stats('run')), PatternEffect.none);
  });

  test('N of 3 upgrades when fatigue stays high', () {
    final book = PatternBook();
    final fatigues = [8.0, 7.0, 9.0];
    for (var i = 0; i < fatigues.length; i++) {
      book.upsert(
        PatternSample(
          key: 'muay_thai:hard>gym:legs_heavy',
          outcomeDate: DateTime(2026, 9, 1 + i),
          readiness: 50,
          fatigue: fatigues[i],
        ),
      );
    }
    final stats = book.stats('muay_thai:hard>gym:legs_heavy');
    expect(stats.n, 3);
    expect(stats.meanFatigue, closeTo(8, 0.01));
    expect(patternEffect(stats), PatternEffect.upgrade);
    expect(
      patternEvidence(stats),
      'Last 3 times: Thai hard → legs heavy. Next-day fatigue 8, 7, 9.',
    );
  });

  test('low readiness upgrades even when fatigue is moderate', () {
    final stats = PatternStats(
      key: 'run',
      n: 3,
      meanReadiness: 44,
      meanFatigue: 5,
      window: const [],
    );
    expect(patternEffect(stats), PatternEffect.upgrade);
  });

  test('easy outcomes downgrade the warning', () {
    final stats = PatternStats(
      key: 'run',
      n: 3,
      meanReadiness: 70,
      meanFatigue: 3,
      window: const [],
    );
    expect(patternEffect(stats), PatternEffect.downgrade);
  });

  test('values between the thresholds keep the default', () {
    final stats = PatternStats(
      key: 'run',
      n: 3,
      meanReadiness: 55,
      meanFatigue: 5,
      window: const [],
    );
    expect(patternEffect(stats), PatternEffect.none);
  });

  test('rolling window keeps the last 8 occurrences', () {
    final book = PatternBook();
    for (var i = 1; i <= 9; i++) {
      book.upsert(
        PatternSample(
          key: 'run',
          outcomeDate: DateTime(2026, 1, i),
          readiness: i.toDouble(),
          fatigue: i.toDouble(),
        ),
      );
    }
    final stats = book.stats('run');
    expect(stats.n, 8);
    expect(stats.window.first.fatigue, 2);
    expect(stats.window.last.fatigue, 9);
    expect(stats.meanFatigue, closeTo((2 + 3 + 4 + 5 + 6 + 7 + 8 + 9) / 8, 0.01));
  });

  test('a second check-in on the same day updates the sample', () {
    final book = PatternBook();
    book.learn(
      outcomeDay: DateTime(2026, 10, 3, 8),
      dayMinus2: [thaiHard()],
      dayMinus1: [legsHeavy()],
      readiness: 40,
      fatigue: 8,
    );
    book.learn(
      outcomeDay: DateTime(2026, 10, 3, 21),
      dayMinus2: [thaiHard()],
      dayMinus1: [legsHeavy()],
      readiness: 55,
      fatigue: 6,
    );
    final stats = book.stats('muay_thai:hard>gym:legs_heavy');
    expect(stats.n, 1);
    expect(stats.meanFatigue, 6);
    expect(stats.meanReadiness, 55);
  });
}
