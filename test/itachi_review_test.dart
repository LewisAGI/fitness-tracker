import 'package:fitness_tracker/services/voice_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  final parser = VoiceParser.seeded();

  test('62.5 kg stays a decimal weight', () {
    final set = parser.parse('bench 3x8 at 62.5 kg').sessions.single.sets.single;
    expect(set.exerciseName, 'Bench press');
    expect(set.weightKg, 62.5);
  });

  test('102.5 stays a decimal weight', () {
    final set = parser.parse('squat 5 by 5 at 102.5').sessions.single.sets.single;
    expect(set.exerciseName, 'Back squat');
    expect(set.weightKg, 102.5);
  });

  test('sixty two point five is 62.5 kg', () {
    final set = parser
        .parse('bench 3x8 at sixty two point five kg')
        .sessions
        .single
        .sets
        .single;
    expect(set.weightKg, 62.5);
  });

  test('and a half is half a kilogram', () {
    final set = parser
        .parse('bench 3x8 at 60 and a half kg')
        .sessions
        .single
        .sets
        .single;
    expect(set.weightKg, 60.5);
  });

  test('bench, squat and rows are three sets and a stray stays as ?', () {
    final result = parser.parse(
      'bench 3x8 at 60 kg, squat 5 by 5 at 100 kg, rows...',
    );
    final sets = result.sessions.single.sets;
    expect(sets.map((set) => set.exerciseName), [
      'Bench press',
      'Back squat',
      'Barbell row',
    ]);
    expect(sets[0].sets, 3);
    expect(sets[0].reps, 8);
    expect(sets[0].weightKg, 60);
    expect(sets[1].sets, 5);
    expect(sets[1].reps, 5);
    expect(sets[1].weightKg, 100);
    final stray = parser.parse(
      'bench 3x8 at 60 kg, notanexercise',
    ).sessions.single.sets;
    expect(stray.last.unmatched, isTrue);
    expect(stray.last.summary, '?');
  });

  test('140 no wait 150 saves 150', () {
    final set = parser
        .parse('bench 3x5 at 140 no wait 150')
        .sessions
        .single
        .sets
        .single;
    expect(set.weightKg, 150);
  });

  test('10 no wait eight saves 8', () {
    final set = parser
        .parse('bench 3 sets of 10 no wait eight at 60 kg')
        .sessions
        .single
        .sets
        .single;
    expect(set.reps, 8);
    expect(set.weightKg, 60);
  });

  test('sorry, I mean and actually replace the earlier number', () {
    expect(
      parser.parse('bench 3x5 at 140 sorry 150').sessions.single.sets.single.weightKg,
      150,
    );
    expect(
      parser.parse('bench 3x5 at 140 I mean 150').sessions.single.sets.single.weightKg,
      150,
    );
    expect(
      parser.parse('bench 3x5 at 140 actually 150').sessions.single.sets.single.weightKg,
      150,
    );
  });

  test('pads 3 rounds and sparring 6 rounds use 3 minutes a round', () {
    final pads = parser.parse('pads 3 rounds').sessions.single;
    expect(pads.blocks.single.subtype, 'pads');
    expect(pads.blocks.single.durationMin, 9);
    expect(pads.blocks.single.rpe, 7);
    expect(pads.durationMin, 9);

    final sparring = parser.parse('sparring 6 rounds').sessions.single;
    expect(sparring.blocks.single.subtype, 'sparring');
    expect(sparring.blocks.single.durationMin, 18);
    expect(sparring.blocks.single.rpe, 8);
    expect(sparring.durationMin, 18);
  });

  test('a custom round length changes the block', () {
    final custom = VoiceParser.seeded();
    final parsed = VoiceParser(
      custom.exercises,
      roundMinutes: 5,
    ).parse('pads 2 rounds').sessions.single;
    expect(parsed.blocks.single.durationMin, 10);
    expect(parsed.durationMin, 10);
  });

  test('a block with no time is ? until the session time is shared', () {
    final open = parser.parse('pads and sparring').sessions.single;
    expect(open.blocks.map((block) => block.durationMin), [null, null]);
    expect(open.durationMin, isNull);
    expect(open.blocks.every((block) => block.summary.contains('?')), isTrue);

    final shared = parser.parse('muay thai 60 minutes pads and sparring').sessions.single;
    expect(shared.blocks.map((block) => block.durationMin), [30, 30]);
    expect(shared.durationMin, 60);
    expect(
      shared.blocks.fold<int>(0, (sum, block) => sum + block.durationMin!),
      shared.durationMin,
    );
  });

  test('bagwork 20 minutes is kept as other and counted', () {
    final session = parser.parse('bagwork 20 minutes').sessions.single;
    expect(session.blocks.single.subtype, 'other');
    expect(session.blocks.single.spoken, 'Bagwork');
    expect(session.blocks.single.durationMin, 20);
    expect(session.durationMin, 20);
    expect(session.type, 'other');
  });

  test('90 minutes pads and sparring splits evenly', () {
    final session = parser.parse('90 minutes pads and sparring').sessions.single;
    expect(session.blocks.map((block) => block.subtype), ['pads', 'sparring']);
    expect(session.blocks.map((block) => block.durationMin), [45, 45]);
    expect(session.durationMin, 90);
    expect(
      session.blocks.fold<int>(0, (sum, block) => sum + block.durationMin!),
      session.durationMin,
    );
  });

  test('3 for 8 and 8 reps 3 sets are 3x8', () {
    final byFor = parser.parse('bench 3 for 8 at 60 kg').sessions.single.sets.single;
    expect(byFor.sets, 3);
    expect(byFor.reps, 8);
    expect(byFor.weightKg, 60);
    final flipped = parser
        .parse('bench 8 reps 3 sets at 60 kg')
        .sessions
        .single
        .sets
        .single;
    expect(flipped.sets, 3);
    expect(flipped.reps, 8);
  });

  test('ran 5 k is 5 km', () {
    final session = parser.parse('ran 5 k').sessions.single;
    expect(session.type, 'run');
    expect(session.distanceKm, 5);
  });

  test('lift phrases map to RIR and leave Muay Thai hard as session RPE', () {
    ParsedSet setOf(String text) => parser.parse(text).sessions.single.sets.single;
    expect(setOf('bench 3x8 at 80 to failure').rir, 0);
    expect(setOf('bench 3x8 at 80 failed').rir, 0);
    expect(setOf('bench 3x8 at 80 near failure').rir, 1);
    expect(setOf('bench 3x8 at 80 nearly failed').rir, 1);
    expect(setOf('bench 3x8 at 80 one left').rir, 1);
    expect(setOf('bench 3x8 at 80 two left').rir, 2);
    expect(setOf('bench 3x8 at 80 easy').rir, 3);
    expect(parser.parse('bench 3x8 at 80 easy').sessions.single.rpe, isNull);
    expect(setOf('bench 3x8 at 80 comfortable').rir, 3);
    expect(setOf('bench 3x8 at 80 RIR 4').rir, 4);
    expect(setOf('bench 3x8 at 80 RPE 8').rir, 2);
    expect(parser.parse('bench 3x8 at 80 RPE 8').sessions.single.rpe, isNull);
    expect(setOf('bench 3x8 at 80').rir, isNull);

    final thai = parser.parse('Muay Thai hard').sessions.single;
    expect(thai.rpe, 7);
    expect(thai.blocks, isEmpty);
  });

  test('saving a log and importing it keep RIR in one read-back', () async {
    final store = await openStore();
    final parsed = parser.parse('bench 3x8 at 80 RIR 2');
    await store.saveParse(parsed);
    final day = await store.loadDay(DateTime(2026, 10, 12));
    final set = day.sessions.single.sets.single;
    expect(set.rir, 2);
    expect(set.exerciseName, 'Bench press');

    final files = await store.exportRange(
      start: DateTime(2026, 10, 12),
      end: DateTime(2026, 10, 12),
      kind: 'week',
    );
    final fresh = await openStore();
    await fresh.importSummary(files.json);
    final imported = await fresh.loadDay(DateTime(2026, 10, 12));
    expect(imported.sessions.single.sets.single.rir, 2);
    expect(files.markdown, contains('RIR 2'));
  });
}
