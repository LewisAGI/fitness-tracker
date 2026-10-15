import 'package:fitness_tracker/services/voice_parser.dart';
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
}
