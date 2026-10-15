import 'package:fitness_tracker/data/exercise_seed.dart';
import 'package:fitness_tracker/services/voice_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = VoiceParser.seeded();

  test('seed dictionary has at least 80 exercises', () {
    expect(seedExercises().length, greaterThanOrEqualTo(80));
  });

  test('bench press, 4 sets of 8 at 70 kilos', () {
    final result = parser.parse('bench press, 4 sets of 8 at 70 kilos');
    final set = result.sessions.single.sets.single;
    expect(set.exerciseName, 'Bench press');
    expect(set.sets, 4);
    expect(set.reps, 8);
    expect(set.weightKg, 70);
    expect(set.summary, 'Bench press · 4×8 · 70 kg');
  });

  test('squats 5 by 5 100k', () {
    final set = parser.parse('squats 5 by 5 100k').sessions.single.sets.single;
    expect(set.exerciseName, 'Back squat');
    expect(set.sets, 5);
    expect(set.reps, 5);
    expect(set.weightKg, 100);
    expect(set.summary, 'Back squat · 5×5 · 100 kg');
  });

  test('Muay Thai, hour and a half, hard', () {
    final session = parser.parse('Muay Thai, hour and a half, hard').sessions.single;
    expect(session.type, 'muay_thai');
    expect(session.durationMin, 90);
    expect(session.rpe, 7);
    expect(session.blocks, isEmpty);
    expect(session.summary, 'Muay Thai · 90 min · RPE 7');
  });

  test('ran 5k in 28 minutes, RPE 6', () {
    final session = parser.parse('ran 5k in 28 minutes, RPE 6').sessions.single;
    expect(session.type, 'run');
    expect(session.distanceKm, 5);
    expect(session.durationMin, 28);
    expect(session.rpe, 6);
    expect(session.summary, 'Run · 5 km · 28 min · RPE 6');
  });

  test('yoga 30 minutes easy', () {
    final session = parser.parse('yoga 30 minutes easy').sessions.single;
    expect(session.type, 'yoga');
    expect(session.durationMin, 30);
    expect(session.rpe, 3);
    expect(session.summary, 'Yoga · 30 min · RPE 3');
  });

  test('pull-ups then rows are two entries in one gym session', () {
    final result = parser.parse(
      'pull-ups 3 sets of 10 bodyweight then rows 3 by 12 at 50',
    );
    expect(result.entryCount, 2);
    final sets = result.sessions.single.sets;
    expect(sets[0].exerciseName, 'Pull-up');
    expect(sets[0].sets, 3);
    expect(sets[0].reps, 10);
    expect(sets[0].bodyweight, isTrue);
    expect(sets[0].summary, 'Pull-up · 3×10 · bodyweight');
    expect(sets[1].exerciseName, 'Barbell row');
    expect(sets[1].sets, 3);
    expect(sets[1].reps, 12);
    expect(sets[1].weightKg, 50);
  });

  test('hour of technique and pads and 30 minutes of clinch', () {
    final session = parser.parse(
      'an hour of technique and pads and 30 minutes of clinch',
    ).sessions.single;
    expect(session.type, 'muay_thai');
    expect(session.blocks, hasLength(3));
    expect(session.blocks.map((block) => block.subtype), [
      'technique',
      'pads',
      'clinch',
    ]);
    expect(session.blocks.map((block) => block.durationMin), [30, 30, 30]);
    expect(session.blocks.map((block) => block.rpe), [4, 7, 8]);
    expect(session.blocks.map((block) => block.load), [120, 210, 240]);
    expect(session.durationMin, 90);
  });

  test('shared duration splits evenly with remainder on the first blocks', () {
    final blocks = parser
        .parse('100 minutes of technique and pads and clinch')
        .sessions
        .single
        .blocks;
    expect(blocks.map((block) => block.durationMin), [34, 33, 33]);
  });

  test('per-block intensity overrides subtype defaults', () {
    final blocks = parser
        .parse('technique easy and sparring hard for 60 minutes')
        .sessions
        .single
        .blocks;
    expect(blocks.map((block) => block.subtype), ['technique', 'sparring']);
    expect(blocks.map((block) => block.durationMin), [30, 30]);
    expect(blocks.map((block) => block.rpe), [3, 7]);
  });

  test('trailing hard applies to every block in the group', () {
    final blocks = parser
        .parse('60 minutes of technique and pads hard')
        .sessions
        .single
        .blocks;
    expect(blocks.map((block) => block.rpe), [7, 7]);
  });

  test('sparring uses its default RPE', () {
    final block = parser.parse('sparring 45 minutes').sessions.single.blocks.single;
    expect(block.subtype, 'sparring');
    expect(block.durationMin, 45);
    expect(block.rpe, 8);
  });

  test('conditioning uses its default RPE', () {
    final block = parser
        .parse('conditioning 20 minutes')
        .sessions
        .single
        .blocks
        .single;
    expect(block.rpe, 6);
    expect(block.durationMin, 20);
  });

  test('clinch default RPE from a duration-of phrase', () {
    final block = parser
        .parse('30 minutes of clinch')
        .sessions
        .single
        .blocks
        .single;
    expect(block.subtype, 'clinch');
    expect(block.rpe, 8);
    expect(block.load, 240);
  });

  test('pounds convert silently to kilograms', () {
    final result = parser.parse('bench press 3 sets of 5 at 100 pounds');
    expect(result.normalised, isNot(contains('pound')));
    expect(result.sessions.single.sets.single.weightKg, 45.4);
  });

  test('miles convert silently to kilometres', () {
    final result = parser.parse('ran 3 miles in 30 minutes');
    expect(result.normalised, isNot(contains('mile')));
    expect(result.sessions.single.distanceKm, 4.83);
    expect(result.sessions.single.durationMin, 30);
  });

  test('five miles becomes 8.05 km', () {
    expect(parser.parse('ran 5 miles').sessions.single.distanceKm, 8.05);
  });

  test('bench rest resolves to bench press', () {
    final set = parser
        .parse('bench rest 4 sets of 8 at 70 kg')
        .sessions
        .single
        .sets
        .single;
    expect(set.exerciseName, 'Bench press');
    expect(set.sets, 4);
    expect(set.weightKg, 70);
  });

  test('fuzzy overhead pres matches overhead press', () {
    final set = parser
        .parse('overhead pres 3 sets of 5 at 40 kg')
        .sessions
        .single
        .sets
        .single;
    expect(set.exerciseName, 'Overhead press');
    expect(set.reps, 5);
    expect(set.weightKg, 40);
  });

  test('another set uses the last exercise', () {
    final bench = seedExercises().firstWhere((exercise) => exercise.name == 'Bench press');
    final set = parser
        .parse('another 2 sets of 8', lastExercise: bench)
        .sessions
        .single
        .sets
        .single;
    expect(set.exerciseName, 'Bench press');
    expect(set.sets, 2);
    expect(set.reps, 8);
  });

  test('unknown exercise stays unmatched', () {
    final set = parser
        .parse('zyzz 3 sets of 8 at 20 kg')
        .sessions
        .single
        .sets
        .single;
    expect(set.unmatched, isTrue);
    expect(set.summary, '? · 3×8 · 20 kg');
  });

  test('done is stripped from the parsed text', () {
    final result = parser.parse('bench press, 4 sets of 8 at 70 kilos done');
    expect(result.normalised, isNot(contains('done')));
    expect(result.sessions.single.sets.single.summary, 'Bench press · 4×8 · 70 kg');
  });

  test("I'm done is stripped", () {
    final result = parser.parse("bench press 4 sets of 8 at 70 I'm done");
    expect(result.normalised.toLowerCase(), isNot(contains('done')));
    expect(result.sessions.single.sets.single.weightKg, 70);
  });

  test('i am done is stripped', () {
    final result = parser.parse('squats 5 by 5 at 100 i am done');
    expect(result.normalised, isNot(contains('done')));
    expect(result.sessions.single.sets.single.exerciseName, 'Back squat');
    expect(result.sessions.single.sets.single.weightKg, 100);
  });

  test('done in the middle is not an end word', () {
    final result = parser.parse('done bench press 4 sets of 8 at 60 kg');
    expect(result.sessions.single.sets.single.exerciseName, 'Bench press');
    expect(result.sessions.single.sets.single.weightKg, 60);
  });

  test('fillers are removed before parsing', () {
    final set = parser
        .parse('um bench press uh 4 sets of 8 at 70 kilos')
        .sessions
        .single
        .sets
        .single;
    expect(set.summary, 'Bench press · 4×8 · 70 kg');
  });

  test('number words become digits', () {
    final set = parser
        .parse('bench press four sets of eight at seventy kilos')
        .sessions
        .single
        .sets
        .single;
    expect(set.sets, 4);
    expect(set.reps, 8);
    expect(set.weightKg, 70);
  });

  test('brutal maps to RPE 9', () {
    expect(parser.parse('muay thai 60 minutes brutal').sessions.single.rpe, 9);
  });

  test('moderate maps to RPE 5', () {
    expect(parser.parse('yoga 20 minutes moderate').sessions.single.rpe, 5);
  });

  test('hike duration is kept in minutes', () {
    final session = parser.parse('hike 2 hours').sessions.single;
    expect(session.type, 'hike');
    expect(session.durationMin, 120);
  });

  test('semicolon splits two lifts', () {
    final sets = parser
        .parse('bench press 3x5 at 60; squat 3x5 at 100')
        .sessions
        .single
        .sets;
    expect(sets.map((set) => set.exerciseName), ['Bench press', 'Back squat']);
    expect(sets[1].weightKg, 100);
  });

  test('and then splits entries', () {
    final sets = parser
        .parse('deadlift 3 sets of 3 at 140 and then lunges 3 sets of 8 at 20')
        .sessions
        .single
        .sets;
    expect(sets[0].exerciseName, 'Deadlift');
    expect(sets[0].weightKg, 140);
    expect(sets[1].exerciseName, 'Lunge');
  });

  test('Tuesday Thai hard, Wednesday legs heavy', () {
    final plans = parser.parse('Tuesday Thai hard, Wednesday legs heavy').plans;
    expect(plans, hasLength(2));
    expect(plans[0].weekday, DateTime.tuesday);
    expect(plans[0].type, 'muay_thai');
    expect(plans[0].intensity, 'hard');
    expect(plans[1].weekday, DateTime.wednesday);
    expect(plans[1].type, 'gym');
    expect(plans[1].muscleGroups, ['legs']);
    expect(plans[1].intensity, 'hard');
  });

  test('half an hour of pads', () {
    final block = parser.parse('half an hour of pads').sessions.single.blocks.single;
    expect(block.subtype, 'pads');
    expect(block.durationMin, 30);
    expect(block.rpe, 7);
  });

  test('explicit kilometres stay kilometres', () {
    expect(parser.parse('ran 10 km').sessions.single.distanceKm, 10);
  });

  test('bodyweight dip', () {
    final set = parser
        .parse('dips 3 sets of 8 bodyweight')
        .sessions
        .single
        .sets
        .single;
    expect(set.exerciseName, 'Dip');
    expect(set.bodyweight, isTrue);
    expect(set.weightKg, isNull);
  });

  test('RDL alias', () {
    expect(
      parser.parse('rdl 3 sets of 8 at 80 kg').sessions.single.sets.single.exerciseName,
      'Romanian deadlift',
    );
  });

  test('front squat wins over squat', () {
    expect(
      parser.parse('front squat 5 by 3 at 90').sessions.single.sets.single.exerciseName,
      'Front squat',
    );
  });
}
