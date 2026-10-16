import 'package:fitness_tracker/data/exercise_seed.dart';
import 'package:fitness_tracker/services/voice_parser.dart';
import 'package:fitness_tracker/widgets/confirm_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  final parser = VoiceParser.seeded();

  ParsedSet setOf(String text) => parser.parse(text).sessions.single.sets.single;

  test('a bare number after a scheme is kilograms', () {
    final bench = setOf('bench 3x8 60');
    expect(bench.exerciseName, 'Bench press');
    expect(bench.sets, 3);
    expect(bench.reps, 8);
    expect(bench.weightKg, 60);
    expect(bench.ambiguous, isFalse);
    expect(bench.lightBar, isFalse);
    expect(bench.summary, isNot(contains('?')));
    expect(parser.parse('bench 3x8 60').imperial, isFalse);

    final squat = setOf('squat 5 by 5 one forty');
    expect(squat.exerciseName, 'Back squat');
    expect(squat.sets, 5);
    expect(squat.reps, 5);
    expect(squat.weightKg, 140);
    expect(squat.ambiguous, isFalse);
    expect(squat.summary, isNot(contains('?')));

    final light = setOf('bench 3x8 15');
    expect(light.weightKg, 15);
    expect(light.lightBar, isTrue);
    expect(light.ambiguous, isFalse);
    expect(light.sets, 3);
    expect(light.reps, 8);
  });

  test('a heart rate phrase does not wipe the set', () {
    final set = setOf('bench 3x8 at 60 heart rate one ten bpm');
    expect(set.exerciseName, 'Bench press');
    expect(set.sets, 3);
    expect(set.reps, 8);
    expect(set.weightKg, 60);
    expect(set.ambiguous, isFalse);
    expect(set.summary, isNot(contains('?')));
    expect(parser.parse('bench 3x8 at 60 heart rate one ten bpm').sessions.single.sets, hasLength(1));

    final bare = setOf('bench 3x8 60 heart rate one ten bpm');
    expect(bare.weightKg, 60);
    expect(bare.sets, 3);
    expect(bare.reps, 8);
    expect(bare.ambiguous, isFalse);
  });

  test('not paused, felt easy does not add a question entry', () {
    final parsed = parser.parse('bench 3x8 at 60 kg not paused, felt easy');
    final sets = parsed.sessions.single.sets;
    expect(sets, hasLength(1));
    expect(sets.single.exerciseName, 'Bench press');
    expect(sets.single.sets, 3);
    expect(sets.single.reps, 8);
    expect(sets.single.weightKg, 60);
    expect(sets.single.rir, 3);
    expect(sets.single.rirFlagged, isFalse);
    expect(sets.single.summary, isNot(contains('?')));
    expect(parsed.sessions.single.summary, isNot(contains('?')));
  });

  test('the RIR negation window stops at a comma or but', () {
    final but = parser.parse('bench 3x8 not easy, but failed');
    expect(but.sessions.single.sets, hasLength(1));
    expect(but.sessions.single.sets.single.rir, 0);
    expect(but.sessions.single.sets.single.rirFlagged, isFalse);
    expect(but.sessions.single.sets.single.summary, isNot(contains('?')));

    final comma = parser.parse("bench 3x8 wasn't easy, to failure");
    expect(comma.sessions.single.sets, hasLength(1));
    expect(comma.sessions.single.sets.single.rir, 0);
    expect(comma.sessions.single.sets.single.rirFlagged, isFalse);
    expect(comma.sessions.single.sets.single.summary, isNot(contains('?')));
  });

  test('I mean replaces a bare weight', () {
    final set = setOf('bench 3x8 at 60 I mean 65');
    expect(set.exerciseName, 'Bench press');
    expect(set.sets, 3);
    expect(set.reps, 8);
    expect(set.weightKg, 65);
    expect(set.ambiguous, isFalse);
    expect(set.summary, 'Bench press · 3×8 · 65 kg');
  });

  test('a rest time is a note and not kilograms', () {
    final bench = parser.parse('bench 3x8 60 seconds rest');
    final set = bench.sessions.single.sets.single;
    expect(set.exerciseName, 'Bench press');
    expect(set.sets, 3);
    expect(set.reps, 8);
    expect(set.weightKg, isNull);
    expect(set.ambiguous, isFalse);
    expect(set.summary, 'Bench press · 3×8');
    expect(bench.sessions.single.notes, contains('bench: 60 seconds rest'));
    expect(set.summary, isNot(contains('60 kg')));

    final rest = parser.parse('90 second rest');
    expect(rest.sessions.single.sets, isEmpty);
    expect(rest.sessions.single.notes, '90 second rest');
    expect(rest.sessions.single.summary, isNot(contains('kg')));
  });

  test('a bare number on a bodyweight exercise is not kilograms', () {
    expect(
      seedExercises().firstWhere((exercise) => exercise.name == 'Pull-up').bodyweight,
      isTrue,
    );
    expect(
      seedExercises().firstWhere((exercise) => exercise.name == 'Bench press').bodyweight,
      isFalse,
    );

    final pull = setOf('pull ups 3x8 10');
    expect(pull.exerciseName, 'Pull-up');
    expect(pull.sets, 3);
    expect(pull.reps, 8);
    expect(pull.weightKg, isNull);
    expect(pull.bodyweight, isFalse);
    expect(pull.loadFlagged, isTrue);
    expect(pull.summary, 'Pull-up · 3×8 · ?');
    expect(confirmNeedsReview(parser.parse('pull ups 3x8 10')), isTrue);

    final push = setOf('push ups 3x20 5');
    expect(push.exerciseName, 'Push-up');
    expect(push.sets, 3);
    expect(push.reps, 20);
    expect(push.weightKg, isNull);
    expect(push.loadFlagged, isTrue);
    expect(confirmNeedsReview(parser.parse('push ups 3x20 5')), isTrue);

    final dip = setOf('dips 3x10 20');
    expect(dip.exerciseName, 'Dip');
    expect(dip.sets, 3);
    expect(dip.reps, 10);
    expect(dip.weightKg, isNull);
    expect(dip.loadFlagged, isTrue);
    expect(confirmNeedsReview(parser.parse('dips 3x10 20')), isTrue);

    final added = setOf('pull ups 3x8 plus 10');
    expect(added.weightKg, 10);
    expect(added.loadFlagged, isFalse);
    expect(added.bodyweight, isFalse);
    expect(confirmNeedsReview(parser.parse('pull ups 3x8 plus 10')), isFalse);

    final explicit = setOf('dips 3x10 added 20 kg');
    expect(explicit.weightKg, 20);
    expect(explicit.loadFlagged, isFalse);
  });

  test('a weight over 300 kg waits for review', () {
    final heavy = setOf('bench 3x8 1000');
    expect(heavy.exerciseName, 'Bench press');
    expect(heavy.sets, 3);
    expect(heavy.reps, 8);
    expect(heavy.weightKg, 1000);
    expect(heavy.heavy, isTrue);
    expect(heavy.ambiguous, isFalse);
    expect(confirmNeedsReview(parser.parse('bench 3x8 1000')), isTrue);
    expect(confirmNeedsReview(parser.parse('bench 3x8 300')), isFalse);
    expect(confirmNeedsReview(parser.parse('bench 3x8 100')), isFalse);
  });

  test('shorter heart rate phrases do not wipe the set', () {
    final hr = setOf('bench 3x8 at 60 hr 150');
    expect(hr.sets, 3);
    expect(hr.reps, 8);
    expect(hr.weightKg, 60);
    expect(hr.ambiguous, isFalse);

    final was = setOf('bench 3x8 at 60 heart rate was one ten');
    expect(was.weightKg, 60);
    expect(was.sets, 3);
    expect(was.reps, 8);
    expect(was.ambiguous, isFalse);
    expect(was.summary, isNot(contains('?')));

    final bpm = setOf('bench 3x8 at 60 150 bpm');
    expect(bpm.weightKg, 60);
    expect(bpm.sets, 3);
    expect(bpm.reps, 8);
    expect(bpm.ambiguous, isFalse);
  });

  test('a weight before the scheme is kilograms', () {
    final squat = setOf('squat 100 5x5');
    expect(squat.exerciseName, 'Back squat');
    expect(squat.sets, 5);
    expect(squat.reps, 5);
    expect(squat.weightKg, 100);
    expect(squat.ambiguous, isFalse);
    expect(squat.summary, 'Back squat · 5×5 · 100 kg');

    final both = setOf('squat 100 5x5 80');
    expect(both.ambiguous, isTrue);
    expect(both.weightKg, isNull);
    expect(confirmNeedsReview(parser.parse('squat 100 5x5 80')), isTrue);
  });

  test('not before the lift flags the card', () {
    final parsed = parser.parse('not deadlift 3x5 at 100');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Deadlift');
    expect(set.sets, 3);
    expect(set.reps, 5);
    expect(set.weightKg, 100);
    expect(set.rejected, isTrue);
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('I mean squat 5x3 at 90 kg replaces the lift and the weight', () {
    final spoken = setOf('I mean squat 5x3 at 90 kg');
    expect(spoken.exerciseName, 'Back squat');
    expect(spoken.sets, 5);
    expect(spoken.reps, 3);
    expect(spoken.weightKg, 90);
    expect(spoken.ambiguous, isFalse);

    final replaced = setOf('bench 3x8 at 60 I mean squat 5x3 at 90 kg');
    expect(replaced.exerciseName, 'Back squat');
    expect(replaced.sets, 5);
    expect(replaced.reps, 3);
    expect(replaced.weightKg, 90);
    expect(replaced.summary, 'Back squat · 5×3 · 90 kg');
  });

  test('rest N does not replace the weight after at or a scheme', () {
    final at = parser.parse('bench 3x8 at 60 rest 90');
    final atSet = at.sessions.single.sets.single;
    expect(at.sessions.single.type, 'gym');
    expect(atSet.sets, 3);
    expect(atSet.reps, 8);
    expect(atSet.weightKg, 60);
    expect(at.sessions.single.notes, contains('bench: rest 90'));
    expect(atSet.summary, 'Bench press · 3×8 · 60 kg');
    expect(confirmNeedsReview(at), isFalse);

    final bare = parser.parse('bench 3x8 60 rest 90');
    final bareSet = bare.sessions.single.sets.single;
    expect(bareSet.weightKg, 60);
    expect(bare.sessions.single.notes, contains('bench: rest 90'));
    expect(bareSet.summary, 'Bench press · 3×8 · 60 kg');
    expect(confirmNeedsReview(bare), isFalse);
  });

  test('a following rest duration does not swallow the weight', () {
    final squat = parser.parse('squat 5x5 100 2 minutes rest');
    final squatSet = squat.sessions.single.sets.single;
    expect(squatSet.sets, 5);
    expect(squatSet.reps, 5);
    expect(squatSet.weightKg, 100);
    expect(squat.sessions.single.notes, contains('squat: 2 minutes rest'));
    expect(squatSet.summary, 'Back squat · 5×5 · 100 kg');
    expect(confirmNeedsReview(squat), isFalse);

    final bench = parser.parse('bench 3x8 at 60 2 minutes rest');
    expect(bench.sessions.single.type, 'gym');
    expect(bench.sessions.single.sets.single.weightKg, 60);
    expect(bench.sessions.single.notes, contains('bench: 2 minutes rest'));
    expect(bench.sessions.single.sets.single.summary, 'Bench press · 3×8 · 60 kg');
    expect(confirmNeedsReview(bench), isFalse);
  });

  test('number words do not cross into a rest duration', () {
    final plate = parser.parse('squat 5x5 one forty two minutes rest');
    final set = plate.sessions.single.sets.single;
    expect(plate.normalised, contains('140'));
    expect(plate.normalised, isNot(contains('142')));
    expect(set.sets, 5);
    expect(set.reps, 5);
    expect(set.weightKg, 140);
    expect(plate.sessions.single.notes, contains('squat: 2 minutes rest'));
    expect(set.summary, 'Back squat · 5×5 · 140 kg');
    expect(confirmNeedsReview(plate), isFalse);

    final hundred = parser.parse('at one hundred, two minutes rest');
    expect(hundred.normalised, contains('100'));
    expect(hundred.normalised, isNot(contains('102')));
    expect(hundred.sessions.single.notes, contains('2 minutes'));
    expect(hundred.sessions.single.summary, isNot(contains('102')));
  });

  test('a lift plus rest minutes stays the gym set', () {
    final parsed = parser.parse('bench 3x8 at 60 rest 2 minutes');
    expect(parsed.sessions, hasLength(1));
    expect(parsed.sessions.single.type, 'gym');
    expect(parsed.sessions.single.summary, isNot(contains('Other')));
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Bench press');
    expect(set.sets, 3);
    expect(set.reps, 8);
    expect(set.weightKg, 60);
    expect(parsed.sessions.single.notes, contains('bench: rest 2 minutes'));
    expect(confirmNeedsReview(parsed), isFalse);
  });

  test('a weight absorbed by a rest note is held for review', () {
    final parsed = parser.parse('bench 3x8 at 60 seconds rest');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Bench press');
    expect(set.sets, 3);
    expect(set.reps, 8);
    expect(set.weightKg, isNull);
    expect(set.loadFlagged, isTrue);
    expect(parsed.sessions.single.notes, contains('60'));
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('two twenty seconds rest is not a plate weight', () {
    final parsed = parser.parse('bench 3x8 two twenty seconds rest');
    final set = parsed.sessions.single.sets.single;
    expect(parsed.sessions.single.type, 'gym');
    expect(set.sets, 3);
    expect(set.reps, 8);
    expect(set.weightKg, isNull);
    expect(set.summary, isNot(contains('220')));
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('at 60 plus 2.5 keeps both plates', () {
    final set = setOf('bench 3x8 at 60 plus 2.5');
    expect(set.sets, 3);
    expect(set.reps, 8);
    expect(set.weightKg, 62.5);
    expect(set.loadFlagged, isFalse);
    expect(set.summary, 'Bench press · 3×8 · 62.5 kg');

    final bare = parser.parse('at 60 plus 2.5');
    final weights = [
      for (final session in bare.sessions)
        for (final row in session.sets) row.weightKg,
    ];
    expect(weights, isNot(contains(2.5)));
    expect(weights.single, anyOf(62.5, isNull));
    if (weights.single == null) {
      expect(confirmNeedsReview(bare), isTrue);
    }
  });

  test('rested 2 minutes does not auto-save another entry', () {
    final alone = parser.parse('rested 2 minutes');
    expect(alone.sessions, hasLength(1));
    expect(alone.sessions.single.summary, contains('?'));
    expect(alone.sessions.single.summary, isNot('Other · 2 min'));
    expect(confirmNeedsReview(alone), isTrue);

    final withLift = parser.parse('bench 3x8 at 60, rested 2 minutes');
    expect(withLift.sessions, hasLength(1));
    expect(withLift.sessions.single.type, 'gym');
    expect(withLift.sessions.single.sets, hasLength(1));
    expect(withLift.sessions.single.sets.single.weightKg, 60);
    expect(withLift.sessions.single.notes, contains('rested'));
    expect(withLift.sessions.where((session) => session.type == 'other'), isEmpty);
  });

  test('hr 150 alone is flagged', () {
    final parsed = parser.parse('hr 150');
    expect(parsed.sessions, hasLength(1));
    expect(parsed.sessions.single.summary, contains('?'));
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('a rest-only segment joins the gym set', () {
    final bench = parser.parse('rest 2 then bench 3x8 at 60');
    expect(bench.sessions, hasLength(1));
    expect(bench.sessions.single.type, 'gym');
    expect(bench.sessions.where((session) => session.type == 'other'), isEmpty);
    final benchSet = bench.sessions.single.sets.single;
    expect(benchSet.exerciseName, 'Bench press');
    expect(benchSet.sets, 3);
    expect(benchSet.reps, 8);
    expect(benchSet.weightKg, 60);
    expect(bench.sessions.single.notes, contains('bench: rest 2'));
    expect(confirmNeedsReview(bench), isFalse);

    final squat = parser.parse('rest 3 minutes then squat 5x5 100');
    expect(squat.sessions, hasLength(1));
    expect(squat.sessions.single.type, 'gym');
    final squatSet = squat.sessions.single.sets.single;
    expect(squatSet.exerciseName, 'Back squat');
    expect(squatSet.sets, 5);
    expect(squatSet.reps, 5);
    expect(squatSet.weightKg, 100);
    expect(squat.sessions.single.notes, contains('squat: rest 3 minutes'));
    expect(confirmNeedsReview(squat), isFalse);
  });

  test('standalone rest is held', () {
    final seconds = parser.parse('rest 90 seconds');
    expect(seconds.sessions, hasLength(1));
    expect(seconds.sessions.single.sets, isEmpty);
    expect(seconds.sessions.single.notes, 'rest 90 seconds');
    expect(seconds.sessions.single.summary, contains('?'));
    expect(seconds.sessions.single.summary, isNot(contains('kg')));
    expect(confirmNeedsReview(seconds), isTrue);

    final minute = parser.parse('rest one minute');
    expect(minute.sessions, hasLength(1));
    expect(minute.sessions.single.sets, isEmpty);
    expect(minute.sessions.single.notes, 'rest 1 minute');
    expect(minute.sessions.single.summary, contains('?'));
    expect(confirmNeedsReview(minute), isTrue);
  });

  test('plus with no base weight is flagged', () {
    final parsed = parser.parse('bench 3x8 plus 2.5');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Bench press');
    expect(set.sets, 3);
    expect(set.reps, 8);
    expect(set.weightKg, isNull);
    expect(set.weightKg, isNot(2.5));
    expect(set.loadFlagged, isTrue);
    expect(set.summary, 'Bench press · 3×8 · ?');
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('for N minutes stays a note on the bench set', () {
    final parsed = parser.parse('bench 3x8 at 60 for 2 minutes');
    expect(parsed.sessions, hasLength(1));
    expect(parsed.sessions.single.type, 'gym');
    expect(parsed.sessions.single.summary, isNot(contains('Other')));
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Bench press');
    expect(set.sets, 3);
    expect(set.reps, 8);
    expect(set.weightKg, 60);
    expect(parsed.sessions.single.notes, 'for 2 minutes');
    expect(confirmNeedsReview(parsed), isFalse);
  });

  test('a comma keeps the plate before a rest phrase', () {
    final parsed = parser.parse('at one forty, rest two minutes');
    expect(parsed.normalised, contains('140'));
    expect(parsed.sessions, hasLength(1));
    final set = parsed.sessions.single.sets.single;
    expect(set.weightKg, 140);
    expect(parsed.sessions.single.notes, contains('2 minutes'));
    expect(set.summary, isNot(contains('1 kg')));
  });

  test('rest 1 30 is a 90 second note and keeps the weight', () {
    final parsed = parser.parse('bench 3x8 at 60 rest 1 30');
    expect(parsed.sessions, hasLength(1));
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Bench press');
    expect(set.sets, 3);
    expect(set.reps, 8);
    expect(set.weightKg, 60);
    expect(parsed.sessions.single.notes, contains('bench: rest 90 seconds'));
    expect(set.summary, isNot(contains('30 kg')));
    expect(confirmNeedsReview(parsed), isFalse);
  });

  test('rest 5x5 is a scheme and not the note rest 5', () {
    final parsed = parser.parse('rest 5x5');
    expect(parsed.sessions.single.notes, isNot('rest 5'));
    final set = parsed.sessions.single.sets.single;
    expect(set.sets, 5);
    expect(set.reps, 5);
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('an empty strength set waits for review', () {
    for (final phrase in ['bench for 10 minutes', 'squat for 20 minutes', 'bench']) {
      final parsed = parser.parse(phrase);
      final set = parsed.sessions.single.sets.single;
      expect(set.category, 'strength', reason: phrase);
      expect(set.sets, isNull, reason: phrase);
      expect(set.reps, isNull, reason: phrase);
      expect(set.weightKg, isNull, reason: phrase);
      expect(set.summary, isNot(contains('?')), reason: phrase);
      expect(confirmNeedsReview(parsed), isTrue, reason: phrase);
    }
    final timed = parser.parse('bench for 10 minutes');
    expect(timed.sessions.single.notes, 'for 10 minutes');
    expect(timed.sessions.single.sets.single.exerciseName, 'Bench press');
    final squat = parser.parse('squat for 20 minutes');
    expect(squat.sessions.single.notes, 'for 20 minutes');
    expect(squat.sessions.single.sets.single.exerciseName, 'Back squat');
  });

  test('a rest note is stored on the set it belongs to', () {
    final parsed = parser.parse('rest 2 then bench 3x8 at 60 then squat 5x5 at 100');
    expect(parsed.sessions, hasLength(1));
    final sets = parsed.sessions.single.sets;
    expect(sets, hasLength(2));
    expect(sets[0].exerciseName, 'Bench press');
    expect(sets[0].weightKg, 60);
    expect(sets[0].notes, 'rest 2');
    expect(sets[1].exerciseName, 'Back squat');
    expect(sets[1].weightKg, 100);
    expect(sets[1].notes, isNull);
    expect(parsed.sessions.single.notes, contains('bench: rest 2'));
  });

  test('a rest before a non-gym session is kept', () {
    final leading = parser.parse('rest 2 then ran 5k');
    expect(leading.sessions.map((session) => session.type), ['other', 'run']);
    expect(leading.sessions.first.notes, 'rest 2');
    expect(leading.sessions.first.summary, contains('?'));
    expect(leading.sessions.last.distanceKm, 5);
    expect(confirmNeedsReview(leading), isTrue);

    final between = parser.parse('bench 3x8 at 60 then rest 2 then ran 5k');
    expect(between.sessions.map((session) => session.type), ['gym', 'run']);
    final bench = between.sessions.first.sets.single;
    expect(bench.weightKg, 60);
    expect(bench.notes, 'rest 2');
    expect(between.sessions.first.notes, contains('bench: rest 2'));
    expect(between.sessions.last.distanceKm, 5);
    expect(between.sessions.last.notes, isNull);
  });

  test('clock rest rejects a minute or second outside range', () {
    final minutes = parser.parse('rest 20 30');
    expect(minutes.sessions.single.notes, 'rest 20');
    expect(minutes.sessions.single.notes, isNot(contains('1230')));
    expect(minutes.sessions.single.sets, isNotEmpty);

    final seconds = parser.parse('rest 1 75');
    expect(seconds.sessions.single.notes, 'rest 1');
    expect(seconds.sessions.single.notes, isNot(contains('135')));
    expect(seconds.sessions.single.sets, isNotEmpty);
  });

  test('a timed bodyweight hold is not empty', () {
    final seconds = parser.parse('plank 60 seconds');
    expect(seconds.sessions.single.sets.single.exerciseName, 'Plank');
    expect(seconds.sessions.single.sets.single.bodyweight, isTrue);
    expect(confirmNeedsReview(seconds), isFalse);

    final timed = parser.parse('plank for 60 seconds');
    expect(timed.sessions.single.sets.single.exerciseName, 'Plank');
    expect(confirmNeedsReview(timed), isFalse);

    final bare = parser.parse('pull ups');
    expect(bare.sessions.single.sets.single.exerciseName, 'Pull-up');
    expect(bare.sessions.single.sets.single.sets, isNull);
    expect(bare.sessions.single.sets.single.reps, isNull);
    expect(bare.sessions.single.sets.single.weightKg, isNull);
    expect(confirmNeedsReview(bare), isTrue);

    final named = parser.parse('pull ups bodyweight');
    expect(named.sessions.single.sets.single.bodyweight, isTrue);
    expect(named.sessions.single.sets.single.explicitBodyweight, isTrue);
    expect(named.sessions.single.sets.single.sets, isNull);
    expect(named.sessions.single.sets.single.reps, isNull);
    expect(confirmNeedsReview(named), isTrue);
  });

  test('a trailing rest is named on the last set and read back', () async {
    final parsed = parser.parse(
      'bench 3x8 at 60 then squat 5x5 at 100 then rest 90',
    );
    final sets = parsed.sessions.single.sets;
    expect(sets, hasLength(2));
    expect(sets.first.notes, isNull);
    expect(sets.last.exerciseName, 'Back squat');
    expect(sets.last.notes, 'rest 90');
    expect(parsed.sessions.single.notes, contains('squat: rest 90'));
    expect(parsed.sessions.single.notes, isNot(contains('bench: rest 90')));

    final store = await openStore();
    await store.saveParse(parsed);
    final day = await store.loadDay(DateTime(2026, 10, 12));
    expect(day.sessions.single.notes, contains('squat: rest 90'));
  });

  test('reps alone do not make a strength set empty', () {
    final result = ParseResult(
      normalised: 'bench 8 reps',
      plans: const [],
      sessions: [
        ParsedSession(
          type: 'gym',
          sets: [
            ParsedSet(
              exerciseName: 'Bench press',
              category: 'strength',
              reps: 8,
            ),
          ],
        ),
      ],
    );
    expect(confirmNeedsReview(result), isFalse);
  });

  test('a rest before a run is its own held card', () {
    final parsed = parser.parse('rest 2 then ran 5k');
    expect(parsed.sessions, hasLength(2));
    expect(parsed.sessions.first.type, 'other');
    expect(parsed.sessions.first.sets, isEmpty);
    expect(parsed.sessions.first.notes, 'rest 2');
    expect(parsed.sessions.first.summary, 'Other · ?');
    expect(parsed.sessions.last.type, 'run');
    expect(parsed.sessions.last.notes, isNull);
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('a rest after a run stays on that session', () {
    final parsed = parser.parse('ran 5k then rest 2');
    expect(parsed.sessions, hasLength(1));
    expect(parsed.sessions.single.type, 'run');
    expect(parsed.sessions.single.distanceKm, 5);
    expect(parsed.sessions.single.notes, 'rest 2');
    expect(parsed.sessions.single.sets, isEmpty);
  });

  testWidgets('the confirm card shows which lift a rest belongs to', (tester) async {
    final parsed = parser.parse('bench 3x8 at 60 rest 90');
    await tester.pumpWidget(
      MaterialApp(
        home: ConfirmCard(
          result: parsed,
          exercises: seedExercises(),
          onSave: (_) async {},
          onAlias: (_, _) async {},
          autoSaveAfter: null,
        ),
      ),
    );
    expect(find.textContaining('bench: rest 90'), findsOneWidget);
  });

  test('a rest duration does not make an empty bodyweight set save', () {
    for (final phrase in [
      'pull ups rest 90 seconds',
      'pull ups, rest 90 seconds',
      'dips rest 2 minutes',
    ]) {
      final parsed = parser.parse(phrase);
      final set = parsed.sessions.single.sets.single;
      expect(set.sets, isNull, reason: phrase);
      expect(set.reps, isNull, reason: phrase);
      expect(set.weightKg, isNull, reason: phrase);
      expect(set.bodyweight, isTrue, reason: phrase);
      expect(confirmNeedsReview(parsed), isTrue, reason: phrase);
    }
  });

  test('editing a session replaces the named rest note', () async {
    final store = await openStore();
    await store.saveParse(parser.parse('bench 3x8 at 60 rest 2 minutes'));
    final saved = await store.loadDay(DateTime(2026, 10, 12));
    expect(saved.sessions.single.notes, 'bench: rest 2 minutes');

    await store.replaceSession(
      saved.sessions.single.id,
      parser.parse('squat 5x5 at 100 rest 3 minutes'),
    );
    final edited = await store.loadDay(DateTime(2026, 10, 12));
    expect(edited.sessions, hasLength(1));
    expect(edited.sessions.single.notes, 'squat: rest 3 minutes');
    expect(edited.sessions.single.notes, isNot(contains('bench')));
  });

  test('for N minutes is kept apart from the following rest', () {
    final bench = parser.parse('bench 3x8 at 60 for 2 minutes rest 90');
    final benchSet = bench.sessions.single.sets.single;
    expect(benchSet.sets, 3);
    expect(benchSet.reps, 8);
    expect(benchSet.weightKg, 60);
    expect(benchSet.summary, 'Bench press · 3×8 · 60 kg');
    expect(bench.sessions.single.notes, contains('for 2 minutes'));
    expect(bench.sessions.single.notes, contains('bench: rest 90'));
    expect(bench.sessions.single.notes, isNot(contains('60×90')));
    expect(confirmNeedsReview(bench), isFalse);

    final squat = parser.parse('squat 5x5 at 100 for 3 minutes rest 2 minutes');
    final squatSet = squat.sessions.single.sets.single;
    expect(squatSet.sets, 5);
    expect(squatSet.reps, 5);
    expect(squatSet.weightKg, 100);
    expect(squat.sessions.single.notes, contains('for 3 minutes'));
    expect(squat.sessions.single.notes, contains('squat: rest 2 minutes'));
    expect(squat.sessions.single.notes, isNot(contains('3 minutes rest')));
    expect(confirmNeedsReview(squat), isFalse);
  });

  test('an implausible scheme waits for review', () {
    final sets = parser.parse('bench 21x8 at 60');
    expect(sets.sessions.single.sets.single.sets, 21);
    expect(sets.sessions.single.sets.single.reps, 8);
    expect(confirmNeedsReview(sets), isTrue);

    final reps = parser.parse('bench 3x101 at 60');
    expect(reps.sessions.single.sets.single.reps, 101);
    expect(confirmNeedsReview(reps), isTrue);

    expect(confirmNeedsReview(parser.parse('bench 20x8 at 60')), isFalse);
    expect(confirmNeedsReview(parser.parse('bench 3x100 at 60')), isFalse);
  });

  test('a rest note is stored once, under the exercise name', () {
    final once = parser.parse('bench 3x8 at 60 rest 90');
    expect(once.sessions.single.notes, 'bench: rest 90');

    final twice = parser.parse('bench 3x8 at 60 rest 90 rest 90');
    expect(twice.sessions.single.notes, 'bench: rest 90');
  });

  test('the same exercise twice names the scheme on the rest', () {
    final parsed = parser.parse(
      'bench 3x8 at 60 rest 2 then bench 3x5 at 70 rest 90',
    );
    final sets = parsed.sessions.single.sets;
    expect(sets, hasLength(2));
    expect(parsed.sessions.single.notes, contains('bench 3x8: rest 2'));
    expect(parsed.sessions.single.notes, contains('bench 3x5: rest 90'));
    expect(parsed.sessions.single.notes, isNot(contains('bench: rest')));
  });

  test('bodyweight is only accepted on a bodyweight exercise', () {
    final bench = parser.parse('bench bodyweight');
    expect(bench.sessions.single.sets.single.exerciseName, 'Bench press');
    expect(bench.sessions.single.sets.single.bodyweight, isFalse);
    expect(bench.sessions.single.sets.single.loadFlagged, isTrue);
    expect(confirmNeedsReview(bench), isTrue);

    final squat = parser.parse('squat bodyweight');
    expect(squat.sessions.single.sets.single.bodyweight, isFalse);
    expect(squat.sessions.single.sets.single.loadFlagged, isTrue);
    expect(confirmNeedsReview(squat), isTrue);
  });

  test('a leading rest stays on the first lift of the run', () {
    final parsed = parser.parse(
      'rest 2 then bench 3x8 at 60 then squat 5x5 at 100',
    );
    final sets = parsed.sessions.single.sets;
    expect(sets, hasLength(2));
    expect(sets.first.exerciseName, 'Bench press');
    expect(sets.first.notes, 'rest 2');
    expect(sets.last.notes, isNull);
    expect(parsed.sessions.single.notes, contains('bench: rest 2'));
    expect(parsed.sessions.single.notes, isNot(contains('squat: rest')));
  });

  test('a rest before a later run stays on the previous lift', () {
    final parsed = parser.parse(
      'row 3x10 at 40 then bench 3x8 at 60 then rest 2 then ran 5k',
    );
    expect(parsed.sessions.map((session) => session.type), ['gym', 'run']);
    final sets = parsed.sessions.first.sets;
    expect(sets, hasLength(2));
    expect(sets.first.exerciseName, 'Barbell row');
    expect(sets.first.notes, isNull);
    expect(sets.last.exerciseName, 'Bench press');
    expect(sets.last.notes, 'rest 2');
    expect(parsed.sessions.first.notes, contains('bench: rest 2'));
    expect(parsed.sessions.last.notes, isNull);
    expect(parsed.sessions.last.distanceKm, 5);
  });

  test('a trailing rest after two lifts needs the gym tail merged', () {
    final parsed = parser.parse(
      'bench 3x8 at 60 then squat 5x5 at 100 then rest 90',
    );
    expect(parsed.sessions, hasLength(1));
    final sets = parsed.sessions.single.sets;
    expect(sets, hasLength(2));
    expect(sets.first.notes, isNull);
    expect(sets.last.notes, 'rest 90');
    expect(parsed.sessions.single.notes, 'squat: rest 90');
  });

  test('a rest between two lifts is named on the previous one', () {
    final parsed = parser.parse(
      'bench 3x8 at 60, rest 2 minutes, squat 5x5 at 100',
    );
    final sets = parsed.sessions.single.sets;
    expect(sets, hasLength(2));
    expect(sets.first.exerciseName, 'Bench press');
    expect(sets.first.weightKg, 60);
    expect(sets.first.notes, 'rest 2 minutes');
    expect(sets.last.exerciseName, 'Back squat');
    expect(sets.last.weightKg, 100);
    expect(sets.last.notes, isNull);
    expect(parsed.sessions.single.notes, 'bench: rest 2 minutes');
    expect(parsed.sessions.single.notes, isNot(contains('squat: rest')));
  });

  test('a timed hold is not cut off by the rep limit', () {
    final parsed = parser.parse('plank 3 x 120 seconds');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Plank');
    expect(set.sets, 3);
    expect(set.bodyweight, isTrue);
    expect(set.notes, contains('120'));
    expect(set.notes, contains('second'));
    expect(confirmNeedsReview(parsed), isFalse);
  });

  test('bodyweight with a scheme is the load', () {
    final parsed = parser.parse('squat 5x5 bodyweight');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Back squat');
    expect(set.sets, 5);
    expect(set.reps, 5);
    expect(set.bodyweight, isTrue);
    expect(set.loadFlagged, isFalse);
    expect(set.summary, 'Back squat · 5×5 · bodyweight');
    expect(confirmNeedsReview(parsed), isFalse);
  });

  test('bodyweight with no reps or duration waits', () {
    final parsed = parser.parse('push ups bodyweight');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Push-up');
    expect(set.sets, isNull);
    expect(set.reps, isNull);
    expect(set.bodyweight, isTrue);
    expect(set.explicitBodyweight, isTrue);
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('a plank duration stays separate from the following rest', () {
    final parsed = parser.parse('plank 60 seconds rest 30');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Plank');
    expect(set.bodyweight, isTrue);
    expect(set.ambiguous, isFalse);
    expect(set.summary, 'Plank · bodyweight');
    expect(set.summary, isNot(contains('?')));
    expect(set.notes, contains('60 seconds'));
    expect(set.notes, contains('rest 30'));
    expect(parsed.sessions.single.notes, contains('plank: rest 30'));
    expect(confirmNeedsReview(parsed), isFalse);
  });

  test('a rest between a run and a bench stays on the bench', () {
    final parsed = parser.parse('ran 5k, rest 2 minutes, bench');
    expect(parsed.sessions.map((session) => session.type), ['run', 'gym']);
    expect(parsed.sessions.first.distanceKm, 5);
    expect(parsed.sessions.first.notes, isNull);
    expect(parsed.sessions.last.sets.single.exerciseName, 'Bench press');
    expect(parsed.sessions.last.sets.single.notes, 'rest 2 minutes');
    expect(parsed.sessions.last.notes, 'bench: rest 2 minutes');
  });

  test('spoken bodyweight does not fill a barbell set', () {
    final result = ParseResult(
      normalised: 'bench bodyweight for 10 minutes',
      plans: const [],
      sessions: [
        ParsedSession(
          type: 'gym',
          sets: [
            ParsedSet(
              exerciseName: 'Bench press',
              category: 'strength',
              explicitBodyweight: true,
              notes: 'for 10 minutes',
            ),
          ],
        ),
      ],
    );
    expect(confirmNeedsReview(result), isTrue);
  });

  test('a barbell scheme said as bodyweight is held', () {
    final bench = parser.parse('bench 5x5 bodyweight');
    final benchSet = bench.sessions.single.sets.single;
    expect(benchSet.exerciseName, 'Bench press');
    expect(benchSet.sets, 5);
    expect(benchSet.reps, 5);
    expect(benchSet.bodyweight, isFalse);
    expect(benchSet.loadFlagged, isTrue);
    expect(benchSet.summary, 'Bench press · 5×5 · ?');
    expect(confirmNeedsReview(bench), isTrue);

    final deadlift = parser.parse('deadlift 5x5 bodyweight');
    final deadliftSet = deadlift.sessions.single.sets.single;
    expect(deadliftSet.exerciseName, 'Deadlift');
    expect(deadliftSet.bodyweight, isFalse);
    expect(deadliftSet.loadFlagged, isTrue);
    expect(confirmNeedsReview(deadlift), isTrue);

    final lunge = parser.parse('lunge 3x10 bodyweight');
    expect(lunge.sessions.single.sets.single.bodyweight, isTrue);
    expect(lunge.sessions.single.sets.single.loadFlagged, isFalse);
    expect(confirmNeedsReview(lunge), isFalse);

    final stepUp = parser.parse('step up 3x10 bodyweight');
    expect(stepUp.sessions.single.sets.single.exerciseName, 'Step-up');
    expect(stepUp.sessions.single.sets.single.bodyweight, isTrue);
    expect(confirmNeedsReview(stepUp), isFalse);
  });

  test('a separate duration does not excuse an implausible scheme', () {
    final parsed = parser.parse('push ups 3x500 for 10 minutes');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Push-up');
    expect(set.sets, 3);
    expect(set.reps, 500);
    expect(set.bodyweight, isTrue);
    expect(set.notes, contains('for 10 minutes'));
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('a weighted timed lift stays under the rep limit', () {
    final parsed = parser.parse('bench 3x120 seconds at 60');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Bench press');
    expect(set.sets, 3);
    expect(set.reps, 120);
    expect(set.weightKg, 60);
    expect(set.bodyweight, isFalse);
    expect(set.notes, contains('120 seconds'));
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('sets without reps do not become a bodyweight load', () {
    final parsed = parser.parse('squat 5 sets bodyweight');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Back squat');
    expect(set.sets, 5);
    expect(set.reps, isNull);
    expect(set.bodyweight, isFalse);
    expect(set.loadFlagged, isTrue);
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('a bodyweight duration beside a huge scheme keeps the set', () {
    final parsed = parser.parse('push ups 30x200 bodyweight 2 minutes');
    expect(parsed.sessions, hasLength(1));
    expect(parsed.sessions.single.type, 'gym');
    expect(parsed.sessions.single.summary, isNot(contains('Other')));
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Push-up');
    expect(set.sets, 30);
    expect(set.reps, 200);
    expect(set.bodyweight, isTrue);
    expect(set.notes, contains('2 minutes'));
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('a rest between a gym tail and a later lift stays on the tail', () {
    final parsed = parser.parse(
      'bench 3x8 at 60 then squat 5x5 at 100 then rest 2 then row 3x10 at 40',
    );
    expect(parsed.sessions, hasLength(1));
    final sets = parsed.sessions.single.sets;
    expect(sets, hasLength(3));
    expect(sets[0].exerciseName, 'Bench press');
    expect(sets[0].notes, isNull);
    expect(sets[1].exerciseName, 'Back squat');
    expect(sets[1].notes, 'rest 2');
    expect(sets[2].exerciseName, 'Barbell row');
    expect(sets[2].notes, isNull);
    expect(parsed.sessions.single.notes, contains('squat: rest 2'));
    expect(parsed.sessions.single.notes, isNot(contains('row: rest')));
    expect(parsed.sessions.single.notes, isNot(contains('bench: rest')));
  });

  test('sets with no reps wait unless the set is timed', () {
    for (final phrase in [
      'bench 3 sets',
      'squat 3 sets at 100',
      'squat 5 sets at 100',
    ]) {
      final parsed = parser.parse(phrase);
      final set = parsed.sessions.single.sets.single;
      expect(set.sets, isNotNull, reason: phrase);
      expect(set.reps, isNull, reason: phrase);
      expect(confirmNeedsReview(parsed), isTrue, reason: phrase);
    }

    final weighted = parser.parse('squat 5 sets at 100');
    expect(weighted.sessions.single.sets.single.weightKg, 100);
    expect(weighted.sessions.single.sets.single.exerciseName, 'Back squat');

    final timed = parser.parse('plank 3 sets for 60 seconds');
    final hold = timed.sessions.single.sets.single;
    expect(hold.exerciseName, 'Plank');
    expect(hold.sets, 3);
    expect(hold.reps, isNull);
    expect(hold.bodyweight, isTrue);
    expect(hold.notes, contains('60 seconds'));
    expect(confirmNeedsReview(timed), isFalse);
  });

  test('a rest of the same count is not the scheme duration', () {
    final parsed = parser.parse('push ups 3x200 rest 200 seconds');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Push-up');
    expect(set.sets, 3);
    expect(set.reps, 200);
    expect(set.bodyweight, isTrue);
    expect(set.notes, contains('rest 200 seconds'));
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('a timed hold longer than 600 seconds waits', () {
    final under = parser.parse('plank 3x500 seconds');
    expect(under.sessions.single.sets.single.reps, 500);
    expect(under.sessions.single.sets.single.bodyweight, isTrue);
    expect(confirmNeedsReview(under), isFalse);

    final edge = parser.parse('plank 3x600 seconds');
    expect(edge.sessions.single.sets.single.reps, 600);
    expect(confirmNeedsReview(edge), isFalse);

    final over = parser.parse('plank 3x601 seconds');
    expect(over.sessions.single.sets.single.reps, 601);
    expect(over.sessions.single.sets.single.notes, contains('601 seconds'));
    expect(confirmNeedsReview(over), isTrue);

    final ten = parser.parse('plank 3x10 minutes');
    expect(ten.sessions.single.sets.single.reps, 10);
    expect(confirmNeedsReview(ten), isFalse);

    final eleven = parser.parse('plank 3x11 minutes');
    expect(eleven.sessions.single.sets.single.reps, 11);
    expect(eleven.sessions.single.sets.single.notes, contains('11 minutes'));
    expect(confirmNeedsReview(eleven), isTrue);
  });

  test('air squat and pistol squat are their own bodyweight moves', () {
    expect(
      seedExercises().firstWhere((exercise) => exercise.name == 'Air squat').bodyweight,
      isTrue,
    );
    expect(
      seedExercises().firstWhere((exercise) => exercise.name == 'Pistol squat').bodyweight,
      isTrue,
    );

    final air = parser.parse('air squat 5x5 bodyweight');
    expect(air.sessions.single.sets.single.exerciseName, 'Air squat');
    expect(air.sessions.single.sets.single.bodyweight, isTrue);
    expect(air.sessions.single.sets.single.loadFlagged, isFalse);
    expect(confirmNeedsReview(air), isFalse);

    final pistol = parser.parse('pistol squat 5x5');
    expect(pistol.sessions.single.sets.single.exerciseName, 'Pistol squat');
    expect(pistol.sessions.single.sets.single.bodyweight, isTrue);
    expect(confirmNeedsReview(pistol), isFalse);

    expect(
      parser.parse('squat 5x5 at 100').sessions.single.sets.single.exerciseName,
      'Back squat',
    );
  });

  test('hip thrust and calf raise can be bodyweight', () {
    expect(
      seedExercises().firstWhere((exercise) => exercise.name == 'Hip thrust').bodyweight,
      isFalse,
    );
    expect(
      seedExercises().firstWhere((exercise) => exercise.name == 'Calf raise').bodyweight,
      isFalse,
    );

    final hip = parser.parse('hip thrust 3x8 bodyweight');
    expect(hip.sessions.single.sets.single.exerciseName, 'Hip thrust');
    expect(hip.sessions.single.sets.single.bodyweight, isTrue);
    expect(hip.sessions.single.sets.single.loadFlagged, isFalse);
    expect(confirmNeedsReview(hip), isFalse);

    final calf = parser.parse('calf raise 3x12 bodyweight');
    expect(calf.sessions.single.sets.single.exerciseName, 'Calf raise');
    expect(calf.sessions.single.sets.single.bodyweight, isTrue);
    expect(confirmNeedsReview(calf), isFalse);

    final weighted = parser.parse('hip thrust 3x8 at 100');
    expect(weighted.sessions.single.sets.single.weightKg, 100);
    expect(weighted.sessions.single.sets.single.bodyweight, isFalse);
    expect(confirmNeedsReview(weighted), isFalse);
  });

  test('a walking lunge with a scheme can be bodyweight', () {
    final parsed = parser.parse('walking lunge 3x10 bodyweight');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Walking lunge');
    expect(set.sets, 3);
    expect(set.reps, 10);
    expect(set.bodyweight, isTrue);
    expect(set.loadFlagged, isFalse);
    expect(confirmNeedsReview(parsed), isFalse);
  });

  test('a seed bodyweight move keeps a spoken scheme', () {
    final parsed = parser.parse('pull ups 5x5 bodyweight');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Pull-up');
    expect(set.sets, 5);
    expect(set.reps, 5);
    expect(set.bodyweight, isTrue);
    expect(set.loadFlagged, isFalse);
    expect(confirmNeedsReview(parsed), isFalse);
  });

  test('a bodyweight duration without a scheme stays held', () {
    final parsed = parser.parse('push ups bodyweight 2 minutes');
    expect(parsed.sessions, hasLength(1));
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Push-up');
    expect(set.sets, isNull);
    expect(set.reps, isNull);
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('a bodyweight duration after a comma stays on the lift', () {
    final parsed = parser.parse('push ups 30x200, bodyweight 2 minutes');
    expect(parsed.sessions, hasLength(1));
    expect(parsed.sessions.single.type, 'gym');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Push-up');
    expect(set.sets, 30);
    expect(set.reps, 200);
    expect(set.notes, contains('2 minutes'));
    expect(confirmNeedsReview(parsed), isTrue);
  });

  test('body weight beside a scheme stays on the lift', () {
    final parsed = parser.parse('push ups 30x200 body weight 2 minutes');
    expect(parsed.sessions, hasLength(1));
    expect(parsed.sessions.single.type, 'gym');
    final set = parsed.sessions.single.sets.single;
    expect(set.exerciseName, 'Push-up');
    expect(set.sets, 30);
    expect(set.reps, 200);
    expect(set.summary, isNot(contains('Other')));
    expect(confirmNeedsReview(parsed), isTrue);
  });
}
