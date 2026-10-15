import 'package:fitness_tracker/models/training.dart';
import 'package:fitness_tracker/services/voice_end_word.dart';
import 'package:fitness_tracker/services/voice_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  final parser = VoiceParser.seeded();

  ParsedSet setOf(String text) => parser.parse(text).sessions.single.sets.single;

  test('negations do not map RIR', () {
    for (final phrase in [
      'not to failure',
      'nowhere near failure',
      'not easy',
      "wasn't easy",
      "didn't easy",
      'wasnt easy',
    ]) {
      final set = setOf('bench 3x8 at 80 $phrase');
      expect(set.rir, isNull, reason: phrase);
      expect(set.rirFlagged, isTrue, reason: phrase);
    }
    final twoBack = setOf('bench 3x8 at 80 wasn\'t really easy');
    expect(twoBack.rir, isNull);
    expect(twoBack.rirFlagged, isTrue);
    final threeBack = setOf('bench 3x8 at 80 didn\'t quite feel easy');
    expect(threeBack.rir, isNull);
    expect(threeBack.rirFlagged, isTrue);
    final hardly = setOf('bench 3x8 at 80 hardly even easy');
    expect(hardly.rir, isNull);
    expect(hardly.rirFlagged, isTrue);
    final barely = setOf('bench 3x8 at 80 barely even that easy');
    expect(barely.rir, isNull);
    expect(barely.rirFlagged, isTrue);
    final fourBack = setOf("bench 3x8 at 80 wasn't really all that easy");
    expect(fourBack.rir, isNull);
    expect(fourBack.rirFlagged, isTrue);
    final acrossBut = setOf('bench 3x8 not easy, but failed');
    expect(acrossBut.rir, 0);
    expect(acrossBut.rirFlagged, isFalse);
    final acrossComma = setOf('bench 3x8 wasn\'t easy, to failure');
    expect(acrossComma.rir, 0);
    expect(acrossComma.rirFlagged, isFalse);
  });

  test('decimals round down so a fraction cannot step up', () {
    final half = setOf('bench 3x8 at 80 RIR 1.5');
    expect(half.rir, 1);
    expect(half.rirFlagged, isFalse);
    expect(setOf('bench 3x8 at 80 RPE 8.5').rir, 1);
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

  test('hundreds are composed before point five', () {
    expect(
      setOf('bench one hundred and two point five kilos').weightKg,
      102.5,
    );
    expect(
      setOf('squat one hundred and twelve point five kilos').weightKg,
      112.5,
    );
    expect(
      setOf('deadlift one hundred and forty two point five kilos').weightKg,
      142.5,
    );
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

    final spoken = setOf('bench 4 sets of 8 I mean 3x10 at 60 kg');
    expect(spoken.sets, 3);
    expect(spoken.reps, 10);
    expect(spoken.weightKg, 60);

    final weight = setOf('bench 3x8 at 80 kg I mean 70');
    expect(weight.sets, 3);
    expect(weight.reps, 8);
    expect(weight.weightKg, 70);

    final schemeKeepsLoad = setOf('bench 4 sets of 8 at 60 I mean 3x10');
    expect(schemeKeepsLoad.sets, 3);
    expect(schemeKeepsLoad.reps, 10);
    expect(schemeKeepsLoad.weightKg, 60);

    final spaced = setOf('bench 3 x 8 at 60 kg I mean 3 x 10');
    expect(spaced.exerciseName, 'Bench press');
    expect(spaced.sets, 3);
    expect(spaced.reps, 10);
    expect(spaced.weightKg, 60);

    final swappedScheme = setOf('bench 3x8 I mean squat 5x3');
    expect(swappedScheme.exerciseName, 'Back squat');
    expect(swappedScheme.sets, 5);
    expect(swappedScheme.reps, 3);
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

  test('failure names the set it belongs to', () async {
    final first = setOf('bench 3x8 failed on the first set');
    expect(first.rir, 0);
    expect(first.rirSetIndex, 0);
    expect(first.rirLastOnly, isFalse);
    final second = setOf('bench 3x8 failed on set 2');
    expect(second.rir, 0);
    expect(second.rirSetIndex, 1);

    final store = await openStore();
    await store.saveParse(parser.parse('bench 3x8 failed on the first set'));
    await store.saveParse(
      parser.parse('row 3x8 failed on set 2'),
      on: DateTime(2026, 10, 13),
    );
    final bench = (await store.loadDay(DateTime(2026, 10, 12))).sessions.single.sets;
    expect(bench.map((set) => set.rir), [0, null, null]);
    final row = (await store.loadDay(DateTime(2026, 10, 13))).sessions.single.sets;
    expect(row.map((set) => set.rir), [null, 0, null]);
  });

  test('a negation on the log does not block a trailing end phrase', () {
    final parser = VoiceParser.seeded();
    final phrases = <String, void Function(ParsedSet set)>{
      'deadlift 5x5 at 140 no wait 150 done': (set) {
        expect(set.exerciseName, 'Deadlift');
        expect(set.sets, 5);
        expect(set.reps, 5);
        expect(set.weightKg, 150);
      },
      'bench 3x8 not to failure done': (set) {
        expect(set.exerciseName, 'Bench press');
        expect(set.sets, 3);
        expect(set.reps, 8);
        expect(set.rir, isNull);
        expect(set.rirFlagged, isTrue);
      },
      "bench 3x8 didn't fail done": (set) {
        expect(set.exerciseName, 'Bench press');
        expect(set.sets, 3);
        expect(set.reps, 8);
        expect(set.rir, isNull);
      },
      'rows 3x10 no straps done': (set) {
        expect(set.exerciseName, 'Barbell row');
        expect(set.sets, 3);
        expect(set.reps, 10);
      },
      'squats 5 by 5 not easy finished': (set) {
        expect(set.exerciseName, 'Back squat');
        expect(set.sets, 5);
        expect(set.reps, 5);
        expect(set.rir, isNull);
        expect(set.rirFlagged, isTrue);
      },
    };
    for (final entry in phrases.entries) {
      expect(VoiceEndWord.endsLog(entry.key), isTrue, reason: entry.key);
      entry.value(parser.parse(entry.key).sessions.single.sets.single);
    }
    expect(VoiceEndWord.endsLog('not done'), isFalse);
    expect(VoiceEndWord.endsLog('not quite done'), isFalse);
    expect(VoiceEndWord.endsLog('not yet finished'), isFalse);
  });

  test('a hundred and a half, oh, and two twenty are plate weights', () {
    expect(
      setOf('bench a hundred and forty two and a half kilos').weightKg,
      142.5,
    );
    expect(setOf('bench one oh two point five kilos').weightKg, 102.5);
    expect(setOf('deadlift two twenty kilos').weightKg, 220);
    expect(setOf('bench at two twenty').weightKg, 220);
    expect(
      setOf('deadlift 5 x 5 at one forty no wait one fifty').weightKg,
      150,
    );
    expect(
      setOf('deadlift 5 x 5 at one forty no wait one fifty').sets,
      5,
    );
    expect(
      setOf('deadlift 5 x 5 at one forty no wait one fifty').reps,
      5,
    );
  });

  test('a filler correction does not wipe the exercise', () {
    for (final phrase in [
      'bench 3 x 8 at 60 kg I mean it was easy',
      'bench 3 x 8 at 60 kg no wait it was easy',
    ]) {
      final set = setOf(phrase);
      expect(set.exerciseName, 'Bench press', reason: phrase);
      expect(set.sets, 3, reason: phrase);
      expect(set.reps, 8, reason: phrase);
      expect(set.weightKg, 60, reason: phrase);
      expect(set.rir, 3, reason: phrase);
    }
    for (final phrase in [
      'bench I mean it felt ok 3 x 8 at 60 kg',
      'bench 3 x 8 I mean at 60 kg',
    ]) {
      final set = setOf(phrase);
      expect(set.exerciseName, 'Bench press', reason: phrase);
      expect(set.sets, 3, reason: phrase);
      expect(set.reps, 8, reason: phrase);
      expect(set.weightKg, 60, reason: phrase);
    }
  });

  test('a barbell under 20 kg is flagged', () {
    expect(setOf('bench 3x8 at 15 kg').lightBar, isTrue);
    expect(setOf('deadlift 3x5 at 19.5 kg').lightBar, isTrue);
    expect(setOf('bench 3x8 at 20 kg').lightBar, isFalse);
    expect(setOf('deadlift 3x5 at 22.5 kg').lightBar, isFalse);
    expect(setOf('curl 3x8 at 12 kg').lightBar, isFalse);
    expect(setOf('bench 3x8 at 80 kg').lightBar, isFalse);
  });

  test('a set number past the entry is flagged and not stored on the last set', () async {
    final fifth = setOf('bench 3x8 failed on set 5');
    expect(fifth.rir, 0);
    expect(fifth.rirSetIndex, 4);
    expect(fifth.rirFlagged, isTrue);
    expect(fifth.rirLastOnly, isFalse);
    final fourth = setOf('bench 3x8 failed on the fourth set');
    expect(fourth.rirSetIndex, 3);
    expect(fourth.rirFlagged, isTrue);
    final zero = setOf('bench 3x8 failed on set 0');
    expect(zero.rirFlagged, isTrue);
    expect(zero.rirLastOnly, isFalse);
    expect(zero.rirSetIndex, -1);

    final store = await openStore();
    await store.saveParse(parser.parse('bench 3x8 failed on set 5'));
    final sets = (await store.loadDay(DateTime(2026, 10, 12))).sessions.single.sets;
    expect(sets, hasLength(1));
    expect(sets.single.setCount, 3);
    expect(sets.single.rir, isNull);
  });

  test('the saved transcript keeps its original case', () async {
    final store = await openStore();
    final parsed = parser.parse('Bench Press 3x8 at 80 kg');
    expect(parsed.sessions.single.raw, 'Bench Press 3x8 at 80 kg');
    await store.saveParse(parsed);
    final day = await store.loadDay(DateTime(2026, 10, 12));
    expect(day.sessions.single.rawTranscript, 'Bench Press 3x8 at 80 kg');
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
