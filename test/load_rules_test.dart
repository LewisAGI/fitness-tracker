import 'package:fitness_tracker/services/load_model.dart';
import 'package:fitness_tracker/services/patterns.dart';
import 'package:fitness_tracker/services/readiness.dart';
import 'package:fitness_tracker/services/rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strength without a duration uses 3 minutes per set', () {
    expect(
      sessionLoad(type: 'gym', rpe: 7, setCount: 4),
      4 * 3 * 7,
    );
  });

  test('missing RPE uses the type default until N reaches 5', () {
    expect(sessionLoad(type: 'run', durationMin: 30), 30 * 6);
    expect(sessionLoad(type: 'hike', durationMin: 60), 60 * 4);
    expect(sessionLoad(type: 'yoga', durationMin: 30), 30 * 2);
    expect(sessionLoad(type: 'muay_thai', durationMin: 90), 90 * 7);
    expect(sessionLoad(type: 'gym', durationMin: 40, intensity: 'hard'), 40 * 7);
    expect(
      sessionLoad(
        type: 'run',
        durationMin: 30,
        rpeSampleCount: 4,
        meanRpe: 8,
      ),
      30 * 6,
    );
    expect(
      sessionLoad(
        type: 'run',
        durationMin: 30,
        rpeSampleCount: 5,
        meanRpe: 8,
      ),
      30 * 8,
    );
  });

  test('Muay Thai block load is the sum of duration times RPE', () {
    expect(
      sessionLoad(
        type: 'muay_thai',
        blocks: const [
          BlockLoad(durationMin: 30, rpe: 4),
          BlockLoad(durationMin: 30, rpe: 7),
          BlockLoad(durationMin: 30, rpe: 8),
        ],
      ),
      570,
    );
  });

  test('muscle-group load sums sets over 72 hours', () {
    final now = DateTime(2026, 10, 12, 18);
    final total = muscleGroupSets(
      muscle: 'legs',
      at: now,
      entries: [
        MuscleSet(
          at: now.subtract(const Duration(hours: 20)),
          muscles: const ['legs', 'quads'],
          sets: 5,
        ),
        MuscleSet(
          at: now.subtract(const Duration(hours: 80)),
          muscles: const ['legs'],
          sets: 4,
        ),
        MuscleSet(
          at: now.subtract(const Duration(hours: 10)),
          muscles: const ['chest'],
          sets: 8,
        ),
      ],
    );
    expect(total, 5);
  });

  test('acute to chronic ratio needs three weeks and uses 1.3', () {
    expect(
      acuteChronicRatio(thisWeek: 200, previousWeeks: const [100, 100]),
      isNull,
    );
    expect(
      acuteChronicRatio(thisWeek: 140, previousWeeks: const [100, 100, 100, 100]),
      greaterThan(1.3),
    );
    expect(
      acuteChronicRatio(thisWeek: 130, previousWeeks: const [100, 100, 100]),
      1.3,
    );
  });

  test('75th percentile flags an unusually heavy load', () {
    final loads = [10.0, 20.0, 30.0, 40.0];
    expect(percentile75(loads), 32.5);
  });

  test('readiness scales 1-10 factors to 0-100 and keeps fatigue', () {
    final full = scoreCheckIns(
      energy: 10,
      sleepQuality: 10,
      mood: 10,
      soreness: 1,
      stress: 1,
      ateWell: 10,
    );
    expect(full!.readiness, closeTo(100, 0.01));
    final low = scoreCheckIns(soreness: 10, energy: 1);
    expect(low!.readiness, closeTo(0, 0.01));
    expect(low.fatigue, 10);
    final mid = scoreCheckIns(energy: 5, sleepQuality: 6);
    expect(mid!.readiness, closeTo(((5.5 - 1) / 9) * 100, 0.01));
  });

  test('morning and evening check-ins both change readiness', () {
    final morning = scoreCheckIns(energy: 8, sleepQuality: 8, mood: 8, soreness: 3, stress: 3);
    final both = scoreCheckIns(
      energy: 8,
      sleepQuality: 8,
      mood: 8,
      soreness: 3,
      stress: 3,
      eveningEnergy: 2,
      ateWell: 2,
      sessionFeel: 2,
      eveningStress: 9,
    );
    expect(both!.readiness, isNot(closeTo(morning!.readiness, 0.01)));
    expect(both.fatigue, isNot(closeTo(morning.fatigue, 0.01)));
  });

  test('two hard days back to back', () {
    final warnings = evaluateRules(
      RulesInput(
        sessions: [
          SessionFact(
            at: DateTime(2026, 10, 11, 18),
            type: 'muay_thai',
            rpe: 8,
            load: 400,
          ),
        ],
        plans: [
          PlanFact(
            date: DateTime(2026, 10, 12),
            type: 'gym',
            intensity: 'hard',
            load: 300,
            muscleGroups: const ['legs'],
          ),
        ],
      ),
    );
    expect(warnings.map((warning) => warning.rule), contains('back_to_back_hard'));
  });

  test('same muscle trained heavy within 48 hours', () {
    final warnings = evaluateRules(
      RulesInput(
        sessions: [
          SessionFact(
            at: DateTime(2026, 10, 11, 9),
            type: 'gym',
            rpe: 8,
            load: 200,
            muscleGroups: const ['chest'],
          ),
        ],
        plans: [
          PlanFact(
            date: DateTime(2026, 10, 12),
            type: 'gym',
            intensity: 'hard',
            load: 200,
            muscleGroups: const ['chest'],
          ),
        ],
      ),
    );
    expect(warnings.map((warning) => warning.rule), contains('muscle_48h'));
  });

  test('heavy legs then running the next day', () {
    final warnings = evaluateRules(
      RulesInput(
        sessions: [
          SessionFact(
            at: DateTime(2026, 10, 11, 9),
            type: 'gym',
            rpe: 8,
            load: 200,
            muscleGroups: const ['legs'],
          ),
        ],
        plans: [
          PlanFact(
            date: DateTime(2026, 10, 12),
            type: 'run',
            intensity: 'easy',
            load: 100,
          ),
        ],
      ),
    );
    expect(
      warnings.single.rule,
      'legs_then_run_thai',
    );
  });

  test('weekly load warning waits for three weeks', () {
    final hidden = evaluateRules(
      RulesInput(
        plans: [
          PlanFact(
            date: DateTime(2026, 10, 12),
            type: 'gym',
            intensity: 'hard',
            load: 400,
          ),
        ],
        sessions: const [],
        previousWeekLoads: const [100, 100],
      ),
    );
    expect(hidden.map((warning) => warning.rule), isNot(contains('weekly_load')));
    final shown = evaluateRules(
      RulesInput(
        plans: [
          PlanFact(
            date: DateTime(2026, 10, 12),
            type: 'gym',
            intensity: 'easy',
            load: 400,
          ),
        ],
        sessions: const [],
        previousWeekLoads: const [100, 100, 100],
      ),
    );
    expect(shown.map((warning) => warning.rule), contains('weekly_load'));
  });

  test('low readiness with a hard plan', () {
    final warnings = evaluateRules(
      RulesInput(
        plans: [
          PlanFact(
            date: DateTime(2026, 10, 12),
            type: 'gym',
            intensity: 'hard',
            load: 200,
          ),
        ],
        sessions: const [],
        readinessByDay: const {'2026-10-12': 39},
      ),
    );
    expect(warnings.single.rule, 'low_readiness');
  });

  test('a learned pattern upgrades a warning that the default rule missed', () {
    final book = PatternBook();
    for (final entry in [
      (DateTime(2026, 9, 1), 8.0),
      (DateTime(2026, 9, 8), 7.0),
      (DateTime(2026, 9, 15), 9.0),
    ]) {
      book.upsert(
        PatternSample(
          key: 'run',
          outcomeDate: entry.$1,
          readiness: 50,
          fatigue: entry.$2,
        ),
      );
    }
    final warnings = evaluateRules(
      RulesInput(
        plans: [
          PlanFact(
            date: DateTime(2026, 10, 12),
            type: 'run',
            intensity: 'easy',
            load: 80,
          ),
        ],
        sessions: const [],
        patterns: book.samples,
      ),
    );
    expect(warnings.single.level, WarningLevel.upgraded);
    expect(warnings.single.evidence, contains('Next-day fatigue 8, 7, 9'));
  });

  test('a benign pattern mutes the default warning', () {
    final book = PatternBook();
    for (final day in [1, 8, 15]) {
      book.upsert(
        PatternSample(
          key: 'muay_thai:hard>gym:legs_heavy',
          outcomeDate: DateTime(2026, 9, day),
          readiness: 70,
          fatigue: 3,
        ),
      );
    }
    final warnings = evaluateRules(
      RulesInput(
        sessions: [
          SessionFact(
            at: DateTime(2026, 10, 11, 18),
            type: 'muay_thai',
            rpe: 8,
            load: 400,
          ),
        ],
        plans: [
          PlanFact(
            date: DateTime(2026, 10, 12),
            type: 'gym',
            intensity: 'hard',
            load: 200,
            muscleGroups: const ['legs'],
          ),
        ],
        patterns: book.samples,
      ),
    );
    expect(warnings, isNotEmpty);
    expect(
      warnings.every((warning) => warning.level == WarningLevel.muted),
      isTrue,
    );
  });
}
