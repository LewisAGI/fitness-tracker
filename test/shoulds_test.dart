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
}
