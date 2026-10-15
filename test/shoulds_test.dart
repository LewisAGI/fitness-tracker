import 'package:fitness_tracker/data/exercise_seed.dart';
import 'package:fitness_tracker/services/voice_parser.dart';
import 'package:fitness_tracker/widgets/confirm_card.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(bench.sessions.single.notes, '60 seconds rest');
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
    expect(at.sessions.single.notes, 'rest 90');
    expect(atSet.summary, 'Bench press · 3×8 · 60 kg');
    expect(confirmNeedsReview(at), isFalse);

    final bare = parser.parse('bench 3x8 60 rest 90');
    final bareSet = bare.sessions.single.sets.single;
    expect(bareSet.weightKg, 60);
    expect(bare.sessions.single.notes, 'rest 90');
    expect(bareSet.summary, 'Bench press · 3×8 · 60 kg');
    expect(confirmNeedsReview(bare), isFalse);
  });

  test('a following rest duration does not swallow the weight', () {
    final squat = parser.parse('squat 5x5 100 2 minutes rest');
    final squatSet = squat.sessions.single.sets.single;
    expect(squatSet.sets, 5);
    expect(squatSet.reps, 5);
    expect(squatSet.weightKg, 100);
    expect(squat.sessions.single.notes, '2 minutes rest');
    expect(squatSet.summary, 'Back squat · 5×5 · 100 kg');
    expect(confirmNeedsReview(squat), isFalse);

    final bench = parser.parse('bench 3x8 at 60 2 minutes rest');
    expect(bench.sessions.single.type, 'gym');
    expect(bench.sessions.single.sets.single.weightKg, 60);
    expect(bench.sessions.single.notes, '2 minutes rest');
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
    expect(plate.sessions.single.notes, '2 minutes rest');
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
    expect(parsed.sessions.single.notes, 'rest 2 minutes');
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
}
