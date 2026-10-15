import 'package:fitness_tracker/models/training.dart';
import 'package:fitness_tracker/services/voice_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  final parser = VoiceParser.seeded();

  ParsedSet setOf(String text) => parser.parse(text).sessions.single.sets.single;

  test('negations do not map RIR', () {
    for (final phrase in ['not to failure', 'nowhere near failure', 'not easy']) {
      final set = setOf('bench 3x8 at 80 $phrase');
      expect(set.rir, isNull, reason: phrase);
      expect(set.rirFlagged, isTrue, reason: phrase);
    }
  });

  test('decimals round half away from zero and out of range is flagged', () {
    final half = setOf('bench 3x8 at 80 RIR 1.5');
    expect(half.rir, 2);
    expect(half.rirFlagged, isFalse);
    expect(setOf('bench 3x8 at 80 RPE 8.5').rir, 2);
    final ten = setOf('bench 3x8 at 80 RIR 10');
    expect(ten.rir, isNull);
    expect(ten.rirFlagged, isTrue);
    expect(setOf('bench 3x8 at 80 RPE 4').rir, isNull);
    expect(setOf('bench 3x8 at 80 RPE 4').rirFlagged, isTrue);
    expect(setOf('bench 3x8 at 80 RPE 11').rir, isNull);
    expect(setOf('bench 3x8 at 80 RPE 11').rirFlagged, isTrue);
  });

  test('failure RIR is only the last set', () {
    for (final phrase in ['failed on last rep', 'to failure']) {
      final set = setOf('bench 3x8 $phrase');
      expect(set.rir, 0, reason: phrase);
      expect(set.rirLastOnly, isTrue, reason: phrase);
      expect(set.sets, 3, reason: phrase);
    }
    expect(setOf('bench 3x8 at 80 RIR 2').rirLastOnly, isFalse);
  });

  test('102 point 5 kilos is 102.5', () {
    expect(setOf('bench 102 point 5 kilos').weightKg, 102.5);
  });

  test('I mean replaces the scheme and actually replaces the exercise', () {
    final scheme = setOf('bench 3x8 I mean 3x10 at 60 kg');
    expect(scheme.exerciseName, 'Bench press');
    expect(scheme.sets, 3);
    expect(scheme.reps, 10);
    expect(scheme.weightKg, 60);

    final swapped = setOf('bench press actually squat 3x5 at 100 kg');
    expect(swapped.exerciseName, 'Back squat');
    expect(swapped.sets, 3);
    expect(swapped.reps, 5);
    expect(swapped.weightKg, 100);
  });

  test('6 rounds of 2 min is 12 minutes', () {
    final session = parser.parse('6 rounds of 2 min').sessions.single;
    expect(session.type, 'muay_thai');
    expect(session.durationMin, 12);

    final pads = parser.parse('pads 6 rounds of 2 min').sessions.single;
    expect(pads.blocks.single.subtype, 'pads');
    expect(pads.blocks.single.durationMin, 12);
    expect(pads.durationMin, 12);
  });

  test('an untimed block stays unknown', () {
    final block = parser.parse('muay thai sparring').sessions.single.blocks.single;
    expect(block.durationMin, isNull);
    expect(block.summary, contains('?'));
    expect(block.summary, isNot(contains('0 min')));
  });

  test('pounds set the imperial flag', () {
    expect(parser.parse('bench 3x8 at 100 pounds').imperial, isTrue);
    expect(parser.parse('ran 3 miles').imperial, isTrue);
    expect(parser.parse('bench 3x8 at 80 kg').imperial, isFalse);
  });

  test('failed on last rep stores RIR 0 on the last set only', () async {
    final store = await openStore();
    await store.saveParse(parser.parse('bench 3x8 failed on last rep'));
    await store.saveParse(
      parser.parse('squat 3x5 to failure'),
      on: DateTime(2026, 10, 13),
    );
    final bench = (await store.loadDay(DateTime(2026, 10, 12))).sessions.single.sets;
    expect(bench.map((set) => set.rir), [null, null, 0]);
    expect(bench.every((set) => set.setCount == 1), isTrue);
    final squat = (await store.loadDay(DateTime(2026, 10, 13))).sessions.single.sets;
    expect(squat.map((set) => set.rir), [null, null, 0]);
  });

  test('import keeps check-ins and plans and rejects a second copy', () async {
    final store = await openStore();
    await store.saveParse(parser.parse('bench 3x8 at 80 RIR 2'));
    await store.saveCheckIn(
      const CheckIn(
        date: '2026-10-12',
        slot: 'morning',
        soreness: 4,
        energy: 7,
        sleepQuality: 6,
        sleepHours: 7.0,
        mood: 6,
        stress: 3,
        ateWell: 8,
      ),
    );
    await store.addPlan(
      date: DateTime(2026, 10, 13),
      type: 'gym',
      muscleGroups: const ['chest'],
      intensity: 'hard',
    );
    final files = await store.exportRange(
      start: DateTime(2026, 10, 12),
      end: DateTime(2026, 10, 13),
      kind: 'week',
    );

    final fresh = await openStore();
    await fresh.importSummary(files.json);
    await fresh.importSummary(files.json);
    final logged = await fresh.loadDay(DateTime(2026, 10, 12));
    expect(logged.sessions, hasLength(1));
    expect(logged.sessions.single.sets.single.rir, 2);
    expect(logged.morning?.energy, 7);
    expect(logged.morning?.sleepHours, 7);
    final planned = await fresh.loadDay(DateTime(2026, 10, 13));
    expect(planned.plans, hasLength(1));
    expect(planned.plans.single.type, 'gym');
    expect(planned.plans.single.muscleGroups, ['chest']);
    expect(planned.plans.single.intensity, 'hard');

    expect(() => fresh.importSummary('{'), throwsFormatException);
    expect(() => fresh.importSummary('[]'), throwsFormatException);
    expect(
      () => fresh.importSummary(
        '{"schema":"other","sessions":[],"checkins":[],"plan":[]}',
      ),
      throwsFormatException,
    );
    expect(
      () => fresh.importSummary(
        '{"schema":"fitness-summary-v1","sessions":{},"checkins":[],"plan":[]}',
      ),
      throwsFormatException,
    );
    expect(
      () => fresh.importSummary(
        '{"schema":"fitness-summary-v1","sessions":[{"type":"gym","sets":[],"blocks":[]}],"checkins":[],"plan":[]}',
      ),
      throwsFormatException,
    );
    final still = await fresh.loadDay(DateTime(2026, 10, 12));
    expect(still.sessions, hasLength(1));
  });
}
