import '../models/training.dart';

List<Exercise> seedExercises() {
  final rows = <_Seed>[
    _s('Bench press', 'strength', ['chest', 'shoulders', 'triceps'], [
      'bench',
      'benchpress',
      'flat bench',
    ]),
    _s('Incline bench press', 'strength', ['chest', 'shoulders'], [
      'incline bench',
      'incline press',
    ]),
    _s('Close-grip bench press', 'strength', ['triceps', 'chest'], [
      'close grip bench',
      'close-grip bench',
    ]),
    _s('Overhead press', 'strength', ['shoulders', 'triceps'], [
      'ohp',
      'shoulder press',
      'military press',
    ]),
    _s('Arnold press', 'strength', ['shoulders'], ['arnold']),
    _s('Landmine press', 'strength', ['shoulders', 'chest'], ['landmine']),
    _s('Back squat', 'strength', ['legs', 'quads', 'glutes'], [
      'squat',
      'squats',
      'back squats',
    ]),
    _s('Front squat', 'strength', ['legs', 'quads'], ['front squats']),
    _s('Goblet squat', 'strength', ['legs', 'quads'], ['goblet']),
    _s('Hack squat', 'strength', ['legs', 'quads'], ['hack squats']),
    _s('Bulgarian split squat', 'strength', ['legs', 'quads', 'glutes'], [
      'bulgarian',
      'split squat',
    ]),
    _s('Deadlift', 'strength', ['back', 'legs', 'glutes', 'hamstrings'], [
      'deadlifts',
      'conventional deadlift',
    ]),
    _s('Sumo deadlift', 'strength', ['legs', 'glutes', 'back'], ['sumo']),
    _s('Romanian deadlift', 'strength', ['hamstrings', 'glutes'], [
      'rdl',
      'romanian',
    ]),
    _s('Rack pull', 'strength', ['back', 'glutes'], ['rack pulls']),
    _s('Good morning', 'strength', ['hamstrings', 'back'], ['good mornings']),
    _s('Barbell row', 'strength', ['back', 'biceps'], [
      'rows',
      'row',
      'bent over row',
      'bent-over row',
    ]),
    _s('Pendlay row', 'strength', ['back'], ['pendlay']),
    _s('Dumbbell row', 'strength', ['back', 'biceps'], ['db row', 'one arm row']),
    _s('Seated row', 'strength', ['back'], ['cable row']),
    _s('Pull-up', 'strength', ['back', 'biceps'], [
      'pull-ups',
      'pullups',
      'pull ups',
      'pullup',
    ], bodyweight: true),
    _s('Chin-up', 'strength', ['back', 'biceps'], [
      'chin-ups',
      'chinups',
      'chin ups',
      'chins',
    ], bodyweight: true),
    _s('Lat pulldown', 'strength', ['back', 'biceps'], ['pulldown', 'lat pull']),
    _s('Face pull', 'strength', ['shoulders', 'back'], ['face pulls']),
    _s('Shrug', 'strength', ['traps'], ['shrugs']),
    _s('Upright row', 'strength', ['shoulders', 'traps'], ['upright rows']),
    _s('Bicep curl', 'strength', ['biceps'], ['curls', 'curl', 'barbell curl']),
    _s('Hammer curl', 'strength', ['biceps'], ['hammer curls']),
    _s('Preacher curl', 'strength', ['biceps'], ['preacher']),
    _s('Concentration curl', 'strength', ['biceps'], ['concentration curls']),
    _s('Tricep pushdown', 'strength', ['triceps'], ['pushdown', 'pressdown']),
    _s('Skull crusher', 'strength', ['triceps'], ['skull crushers']),
    _s('Dip', 'strength', ['chest', 'triceps'], ['dips'], bodyweight: true),
    _s('Lateral raise', 'strength', ['shoulders'], ['lat raises', 'side raise']),
    _s('Reverse fly', 'strength', ['shoulders', 'back'], ['rear delt fly']),
    _s('Chest fly', 'strength', ['chest'], ['flyes', 'flies', 'dumbbell fly']),
    _s('Push-up', 'strength', ['chest', 'triceps', 'shoulders'], [
      'push-ups',
      'pushups',
      'push ups',
      'press-ups',
      'press ups',
    ], bodyweight: true),
    _s('Leg press', 'strength', ['legs', 'quads', 'glutes'], ['leg presses']),
    _s('Leg curl', 'strength', ['hamstrings'], ['leg curls', 'hamstring curl']),
    _s('Leg extension', 'strength', ['quads'], ['leg extensions']),
    _s('Calf raise', 'strength', ['calves'], ['calf raises', 'calves']),
    _s('Seated calf raise', 'strength', ['calves'], ['seated calves']),
    _s('Hip thrust', 'strength', ['glutes'], ['hip thrusts']),
    _s('Glute bridge', 'strength', ['glutes'], ['glute bridges'], bodyweight: true),
    _s('Hip abductor', 'strength', ['glutes'], ['abductor', 'abductions']),
    _s('Hip adductor', 'strength', ['legs'], ['adductor', 'adductions']),
    _s('Lunge', 'strength', ['legs', 'quads', 'glutes'], ['lunges']),
    _s('Walking lunge', 'strength', ['legs', 'quads', 'glutes'], [
      'walking lunges',
    ]),
    _s('Step-up', 'strength', ['legs', 'quads', 'glutes'], ['step ups', 'stepups']),
    _s('Nordic curl', 'strength', ['hamstrings'], [
      'nordics',
      'nordic curls',
    ], bodyweight: true),
    _s('Power clean', 'strength', ['full', 'legs', 'back'], ['cleans', 'power cleans']),
    _s('Hang clean', 'strength', ['full', 'legs', 'back'], ['hang cleans']),
    _s('Snatch', 'strength', ['full', 'legs', 'shoulders'], ['snatches']),
    _s('Thruster', 'strength', ['legs', 'shoulders'], ['thrusters']),
    _s('Kettlebell swing', 'strength', ['glutes', 'hamstrings', 'back'], [
      'swings',
      'kb swing',
    ]),
    _s('Farmer carry', 'strength', ['traps', 'core'], ['farmers carry', 'farmer walk']),
    _s('Box jump', 'strength', ['legs'], ['box jumps']),
    _s('Sit-up', 'strength', ['core'], ['sit-ups', 'situps', 'sit ups'], bodyweight: true),
    _s('Plank', 'strength', ['core'], ['planks'], bodyweight: true),
    _s('Side plank', 'strength', ['core'], ['side planks'], bodyweight: true),
    _s('Hanging leg raise', 'strength', ['core'], ['leg raises'], bodyweight: true),
    _s('Ab wheel', 'strength', ['core'], ['ab wheel rollouts', 'rollouts']),
    _s('Russian twist', 'strength', ['core'], ['russian twists']),
    _s('Pallof press', 'strength', ['core'], ['pallof']),
    _s('Toes to bar', 'strength', ['core'], ['t2b', 'toes-to-bar'], bodyweight: true),
    _s('Wrist curl', 'strength', ['forearms'], ['wrist curls']),
    _s('Burpee', 'strength', ['full'], ['burpees'], bodyweight: true),
    _s('Wall sit', 'strength', ['legs', 'quads'], ['wall sits'], bodyweight: true),
    _s('Muscle-up', 'strength', ['back', 'chest', 'triceps'], [
      'muscle ups',
      'muscleups',
    ], bodyweight: true),
    _s('Run', 'cardio', ['legs'], ['ran', 'running', 'jog', 'jogged']),
    _s('Treadmill', 'cardio', ['legs'], ['treadmill run']),
    _s('Incline walk', 'cardio', ['legs'], ['incline walking']),
    _s('Rowing machine', 'cardio', ['back', 'legs'], ['erg', 'rowing']),
    _s('Bike', 'cardio', ['legs'], ['cycle', 'cycling', 'bike ride']),
    _s('Assault bike', 'cardio', ['legs', 'full'], ['air bike', 'echo bike']),
    _s('Ski erg', 'cardio', ['back', 'core'], ['ski-erg', 'skierg']),
    _s('Swim', 'cardio', ['full'], ['swimming', 'swam']),
    _s('Jump rope', 'cardio', ['calves'], ['skipping', 'skip']),
    _s('Hike', 'cardio', ['legs'], ['hike', 'hiked', 'hiking']),
    _s('Muay Thai', 'combat', ['full'], ['muay thai', 'thai', 'muaythai']),
    _s('Boxing', 'combat', ['shoulders', 'core'], ['boxing']),
    _s('Bag work', 'combat', ['shoulders', 'core'], ['bag', 'heavy bag']),
    _s('Shadow boxing', 'combat', ['shoulders'], ['shadowboxing', 'shadow box']),
    _s('Yoga', 'mobility', ['full'], ['yoga']),
    _s('Stretching', 'mobility', ['full'], ['stretch', 'stretches']),
    _s('Mobility', 'mobility', ['full'], ['mobility work']),
    _s('Foam roll', 'mobility', ['full'], ['foam rolling']),
    _s('Pilates', 'mobility', ['core'], ['pilates']),
    _s('Air squat', 'strength', ['legs', 'quads', 'glutes'], [
      'air squats',
    ], bodyweight: true),
    _s('Pistol squat', 'strength', ['legs', 'quads', 'glutes'], [
      'pistol squats',
    ], bodyweight: true),
  ];
  return [
    for (var i = 0; i < rows.length; i++)
      Exercise(
        id: i + 1,
        name: rows[i].name,
        category: rows[i].category,
        muscleGroups: rows[i].muscles,
        aliases: rows[i].aliases,
        bodyweight: rows[i].bodyweight,
      ),
  ];
}

class _Seed {
  const _Seed(
    this.name,
    this.category,
    this.muscles,
    this.aliases, {
    this.bodyweight = false,
  });
  final String name;
  final String category;
  final List<String> muscles;
  final List<String> aliases;
  final bool bodyweight;
}

bool seededBodyweight(String name) {
  for (final exercise in seedExercises()) {
    if (exercise.name == name) {
      return exercise.bodyweight;
    }
  }
  return false;
}

_Seed _s(
  String name,
  String category,
  List<String> muscles,
  List<String> aliases, {
  bool bodyweight = false,
}) => _Seed(name, category, muscles, aliases, bodyweight: bodyweight);
