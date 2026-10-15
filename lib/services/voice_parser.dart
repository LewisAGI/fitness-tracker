import '../data/exercise_seed.dart';
import '../models/training.dart';
import 'normalise.dart';

const thaiBlockRpe = <String, int>{
  'technique': 4,
  'pads': 7,
  'clinch': 8,
  'sparring': 8,
  'conditioning': 6,
};

const intensityRpe = <String, int>{
  'easy': 3,
  'light': 3,
  'moderate': 5,
  'hard': 7,
  'heavy': 7,
  'brutal': 9,
};

const _subtypeCanonical = <String, String>{
  'technique': 'technique',
  'tech': 'technique',
  'pad work': 'pads',
  'pads': 'pads',
  'clinching': 'clinch',
  'clinch': 'clinch',
  'sparring': 'sparring',
  'spar': 'sparring',
  'conditioning': 'conditioning',
};

const _weekday = <String, int>{
  'monday': DateTime.monday,
  'mon': DateTime.monday,
  'tuesday': DateTime.tuesday,
  'tues': DateTime.tuesday,
  'tue': DateTime.tuesday,
  'wednesday': DateTime.wednesday,
  'weds': DateTime.wednesday,
  'wed': DateTime.wednesday,
  'thursday': DateTime.thursday,
  'thurs': DateTime.thursday,
  'thur': DateTime.thursday,
  'thu': DateTime.thursday,
  'friday': DateTime.friday,
  'fri': DateTime.friday,
  'saturday': DateTime.saturday,
  'sat': DateTime.saturday,
  'sunday': DateTime.sunday,
  'sun': DateTime.sunday,
};

class ParsedSet {
  ParsedSet({
    this.exerciseId,
    this.exerciseName,
    this.spoken = '',
    this.sets,
    this.reps,
    this.weightKg,
    this.bodyweight = false,
    this.unmatched = false,
    this.muscleGroups = const [],
    this.category,
  });

  int? exerciseId;
  String? exerciseName;
  String spoken;
  int? sets;
  int? reps;
  double? weightKg;
  bool bodyweight;
  bool unmatched;
  List<String> muscleGroups;
  String? category;

  String get summary {
    final name = unmatched || exerciseName == null ? '?' : exerciseName!;
    final setCount = sets;
    final repCount = reps;
    final load = bodyweight
        ? 'bodyweight'
        : weightKg != null
        ? '${fmtKg(weightKg!)} kg'
        : null;
    if (setCount != null && repCount != null) {
      final core = '$name · $setCount×$repCount';
      return load == null ? core : '$core · $load';
    }
    if (load != null) {
      return '$name · $load';
    }
    return name;
  }
}

class ParsedBlock {
  ParsedBlock({
    required this.subtype,
    required this.durationMin,
    required this.rpe,
  });

  String subtype;
  int durationMin;
  int rpe;

  double get load => durationMin * rpe.toDouble();

  String get label => switch (subtype) {
    'technique' => 'Technique',
    'pads' => 'Pads',
    'clinch' => 'Clinch',
    'sparring' => 'Sparring',
    'conditioning' => 'Conditioning',
    _ => subtype,
  };

  String get summary => '$label · $durationMin min · RPE $rpe · ${load.round()}';
}

class ParsedSession {
  ParsedSession({
    required this.type,
    this.durationMin,
    this.rpe,
    this.distanceKm,
    List<ParsedSet>? sets,
    List<ParsedBlock>? blocks,
    this.raw = '',
  }) : sets = sets ?? <ParsedSet>[],
       blocks = blocks ?? <ParsedBlock>[];

  String type;
  int? durationMin;
  int? rpe;
  double? distanceKm;
  final List<ParsedSet> sets;
  final List<ParsedBlock> blocks;
  String raw;

  String get summary {
    final bits = <String>[_typeLabel(type)];
    if (distanceKm != null) {
      bits.add('${fmtKm(distanceKm!)} km');
    }
    if (durationMin != null && blocks.isEmpty) {
      bits.add('$durationMin min');
    } else if (durationMin != null && blocks.isNotEmpty) {
      bits.add('$durationMin min');
    }
    if (rpe != null && blocks.isEmpty) {
      bits.add('RPE $rpe');
    }
    if (sets.length == 1 && type == 'gym') {
      return sets.single.summary;
    }
    return bits.join(' · ');
  }
}

class ParsedPlan {
  ParsedPlan({
    required this.weekday,
    required this.type,
    this.muscleGroups = const [],
    this.intensity,
    this.durationMin,
  });

  final int weekday;
  final String type;
  final List<String> muscleGroups;
  final String? intensity;
  final int? durationMin;

  String get summary {
    final bits = <String>[_typeLabel(type)];
    if (muscleGroups.isNotEmpty) {
      bits.add(muscleGroups.join(', '));
    }
    if (intensity != null) {
      bits.add(intensity!);
    }
    if (durationMin != null) {
      bits.add('$durationMin min');
    }
    return bits.join(' · ');
  }
}

class ParseResult {
  const ParseResult({
    required this.normalised,
    required this.sessions,
    required this.plans,
  });

  final String normalised;
  final List<ParsedSession> sessions;
  final List<ParsedPlan> plans;

  int get entryCount => sessions.fold<int>(
    0,
    (sum, session) => sum + (session.sets.isEmpty ? 1 : session.sets.length),
  );
}

class VoiceParser {
  VoiceParser(this.exercises);

  final List<Exercise> exercises;

  factory VoiceParser.seeded() => VoiceParser(seedExercises());

  ParseResult parse(String input, {Exercise? lastExercise}) {
    final normalised = normaliseTranscript(input);
    if (_hasWeekday(normalised)) {
      return ParseResult(
        normalised: normalised,
        sessions: const [],
        plans: _parsePlans(normalised),
      );
    }
    final parts = _splitLog(normalised);
    final parsed = <ParsedSession>[];
    Exercise? last = lastExercise;
    for (final part in parts) {
      if (part.trim().isEmpty) {
        continue;
      }
      final session = _parseEntry(part.trim(), last);
      parsed.add(session);
      for (final set in session.sets.reversed) {
        if (set.exerciseId != null) {
          for (final exercise in exercises) {
            if (exercise.id == set.exerciseId) {
              last = exercise;
              break;
            }
          }
          break;
        }
      }
    }
    return ParseResult(
      normalised: normalised,
      sessions: _mergeGym(parsed),
      plans: const [],
    );
  }

  ParsedSession _parseEntry(String text, Exercise? lastExercise) {
    final blocks = _parseBlocks(text);
    final thai = _mentionsThai(text) || blocks.isNotEmpty;
    if (thai) {
      final duration = blocks.isEmpty
          ? _durationMinutes(text)
          : blocks.fold<int>(0, (sum, block) => sum + block.durationMin);
      final explicit = _explicitRpe(text);
      final weighted = blocks.isEmpty ? null : _weightedRpe(blocks);
      return ParsedSession(
        type: 'muay_thai',
        durationMin: duration,
        rpe: explicit ?? weighted ?? _bareIntensity(text),
        blocks: blocks,
        raw: text,
      );
    }

    final match = _matchExercise(exercises, text);
    if (_isRun(text, match)) {
      return ParsedSession(
        type: 'run',
        durationMin: _durationMinutes(text),
        rpe: _explicitRpe(text) ?? _bareIntensity(text),
        distanceKm: _distanceKm(text),
        raw: text,
      );
    }
    if (_isHike(text, match)) {
      return ParsedSession(
        type: 'hike',
        durationMin: _durationMinutes(text),
        rpe: _explicitRpe(text) ?? _bareIntensity(text),
        distanceKm: _distanceKm(text),
        raw: text,
      );
    }
    if (_isYoga(text, match)) {
      return ParsedSession(
        type: 'yoga',
        durationMin: _durationMinutes(text),
        rpe: _explicitRpe(text) ?? _bareIntensity(text),
        raw: text,
      );
    }

    if (match != null &&
        match.exercise.category == 'cardio' &&
        match.exercise.name != 'Run' &&
        match.exercise.name != 'Hike') {
      return ParsedSession(
        type: 'other',
        durationMin: _durationMinutes(text),
        rpe: _explicitRpe(text) ?? _bareIntensity(text),
        distanceKm: _distanceKm(text),
        raw: text,
      );
    }
    if (match != null &&
        (match.exercise.category == 'mobility' ||
            match.exercise.category == 'combat')) {
      final type = match.exercise.name == 'Yoga'
          ? 'yoga'
          : match.exercise.name == 'Muay Thai'
          ? 'muay_thai'
          : 'other';
      return ParsedSession(
        type: type,
        durationMin: _durationMinutes(text),
        rpe: _explicitRpe(text) ?? _bareIntensity(text),
        raw: text,
      );
    }

    final slots = _strengthSlots(text);
    Exercise? exercise = match?.exercise;
    var unmatched = false;
    var spoken = match?.alias ?? _exerciseFragment(text);
    if (exercise == null && (slots.sets != null || slots.reps != null)) {
      if (lastExercise != null) {
        exercise = lastExercise;
        spoken = _exerciseFragment(text);
      } else {
        unmatched = true;
      }
    } else if (exercise == null) {
      unmatched = true;
    }

    return ParsedSession(
      type: 'gym',
      rpe: _explicitRpe(text) ?? _bareIntensity(text),
      raw: text,
      sets: [
        ParsedSet(
          exerciseId: exercise?.id,
          exerciseName: exercise?.name,
          spoken: spoken,
          sets: slots.sets,
          reps: slots.reps,
          weightKg: slots.weightKg,
          bodyweight: slots.bodyweight,
          unmatched: unmatched,
          muscleGroups: exercise?.muscleGroups ?? const [],
          category: exercise?.category,
        ),
      ],
    );
  }

  List<ParsedBlock> _parseBlocks(String text) {
    final blocks = <ParsedBlock>[];
    final consumed = List<bool>.filled(text.length, false);
    final ofRe = RegExp(
      r'(\d+(?:\.\d+)?)\s*(hours|hour|hrs|hr|minutes|mins|min)\s+of\s+(.+?)(?=(?:\s+and\s+)?\d+(?:\.\d+)?\s*(?:hours|hour|hrs|hr|minutes|mins|min)\s+of\b|$)',
    );
    for (final match in ofRe.allMatches(text)) {
      final subs = _subtypeChunk(match.group(3)!);
      if (subs.isEmpty) {
        continue;
      }
      for (var i = match.start; i < match.end; i++) {
        consumed[i] = true;
      }
      final minutes = _unitMinutes(match.group(1)!, match.group(2)!);
      final shares = splitMinutes(minutes, subs.length);
      final sessionTone = _bareIntensity(text);
      for (var i = 0; i < subs.length; i++) {
        blocks.add(
          ParsedBlock(
            subtype: subs[i].subtype,
            durationMin: shares[i],
            rpe: subs[i].rpe ?? sessionTone ?? thaiBlockRpe[subs[i].subtype]!,
          ),
        );
      }
    }

    final rest = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (!consumed[i]) {
        rest.write(text[i]);
      }
    }
    final subtypeAlt =
        'technique|tech|pad work|pads|clinching|clinch|sparring|spar|conditioning';
    final tone = 'easy|light|moderate|hard|heavy|brutal';
    final forRe = RegExp(
      '((?:$subtypeAlt)(?:\\s+(?:$tone))?(?:\\s+(?:and|plus|,)\\s+(?:$subtypeAlt)(?:\\s+(?:$tone))?)*)\\s+(?:for\\s+)?(\\d+(?:\\.\\d+)?)\\s*(hours|hour|hrs|hr|minutes|mins|min)\\b',
    );
    final remainder = rest.toString();
    for (final match in forRe.allMatches(remainder)) {
      final subs = _subtypeChunk(match.group(1)!);
      if (subs.isEmpty) {
        continue;
      }
      final minutes = _unitMinutes(match.group(2)!, match.group(3)!);
      final shares = splitMinutes(minutes, subs.length);
      final sessionTone = _bareIntensity(text);
      for (var i = 0; i < subs.length; i++) {
        blocks.add(
          ParsedBlock(
            subtype: subs[i].subtype,
            durationMin: shares[i],
            rpe: subs[i].rpe ?? sessionTone ?? thaiBlockRpe[subs[i].subtype]!,
          ),
        );
      }
    }
    return blocks;
  }
}

class _SubHit {
  const _SubHit(this.subtype, this.rpe);
  final String subtype;
  final int? rpe;
}

class _ExerciseHit {
  const _ExerciseHit(this.exercise, this.alias, this.distance);
  final Exercise exercise;
  final String alias;
  final int distance;
}

class _Slots {
  const _Slots({this.sets, this.reps, this.weightKg, this.bodyweight = false});
  final int? sets;
  final int? reps;
  final double? weightKg;
  final bool bodyweight;
}

List<int> splitMinutes(int total, int parts) {
  if (parts <= 0) {
    return const [];
  }
  final base = total ~/ parts;
  var remainder = total % parts;
  return List<int>.generate(parts, (index) {
    final extra = remainder > 0 ? 1 : 0;
    if (remainder > 0) {
      remainder--;
    }
    return base + extra;
  });
}

bool _hasWeekday(String text) {
  for (final name in _weekday.keys) {
    if (RegExp('\\b$name\\b').hasMatch(text)) {
      return true;
    }
  }
  return false;
}

List<String> _splitLog(String text) {
  return text
      .split(RegExp(r'\s*(?:;|and then|then)\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

List<ParsedPlan> _parsePlans(String text) {
  final parts = text
      .split(RegExp(r'\s*(?:,|;)\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty);
  final plans = <ParsedPlan>[];
  int? day;
  for (final part in parts) {
    final found = _weekdayIn(part);
    if (found != null) {
      day = found;
    }
    if (day == null) {
      continue;
    }
    final type = _planType(part);
    final muscles = _planMuscles(part);
    if (type == null && muscles.isEmpty) {
      continue;
    }
    plans.add(
      ParsedPlan(
        weekday: day,
        type: type ?? 'gym',
        muscleGroups: muscles,
        intensity: _planIntensity(part),
        durationMin: _durationMinutes(part),
      ),
    );
  }
  return plans;
}

int? _weekdayIn(String text) {
  const ordered = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'saturday',
    'friday',
    'sunday',
    'thurs',
    'tues',
    'weds',
    'thur',
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];
  for (final name in ordered) {
    if (RegExp('\\b$name\\b').hasMatch(text)) {
      return _weekday[name];
    }
  }
  return null;
}

String? _planType(String text) {
  if (_mentionsThai(text)) {
    return 'muay_thai';
  }
  if (RegExp(r'\b(run|running|jog)\b').hasMatch(text)) {
    return 'run';
  }
  if (RegExp(r'\bhik(?:e|ed|ing)\b').hasMatch(text)) {
    return 'hike';
  }
  if (RegExp(r'\byoga\b').hasMatch(text)) {
    return 'yoga';
  }
  if (_planMuscles(text).isNotEmpty || RegExp(r'\bgym\b').hasMatch(text)) {
    return 'gym';
  }
  return null;
}

List<String> _planMuscles(String text) {
  const names = [
    'legs',
    'quads',
    'hamstrings',
    'glutes',
    'chest',
    'back',
    'shoulders',
    'arms',
    'core',
    'calves',
  ];
  return [
    for (final name in names)
      if (RegExp('\\b$name\\b').hasMatch(text)) name,
  ];
}

String? _planIntensity(String text) {
  if (RegExp(r'\b(easy|light)\b').hasMatch(text)) {
    return 'easy';
  }
  if (RegExp(r'\bmoderate\b').hasMatch(text)) {
    return 'moderate';
  }
  if (RegExp(r'\b(hard|heavy|brutal)\b').hasMatch(text)) {
    return 'hard';
  }
  return null;
}

bool _mentionsThai(String text) =>
    RegExp(r'\bmuay\s*thai\b|\bmuaythai\b|\bthai\b').hasMatch(text);

bool _mentionsSubtype(String text) {
  for (final alias in _subtypeCanonical.keys) {
    if (RegExp('\\b${RegExp.escape(alias)}\\b').hasMatch(text)) {
      return true;
    }
  }
  return false;
}

List<_SubHit> _subtypeChunk(String chunk) {
  final parts = chunk.split(RegExp(r'\s*(?:,|\band\b|\bplus\b)\s*'));
  final found = <_SubHit>[];
  int? orphanTone;
  for (final part in parts) {
    final subtype = _subtypeIn(part);
    final tone = _intensityIn(part);
    if (subtype == null) {
      if (tone != null) {
        orphanTone = tone;
      }
      continue;
    }
    found.add(_SubHit(subtype, tone));
  }
  if (found.isEmpty) {
    return found;
  }
  if (orphanTone != null && found.every((hit) => hit.rpe == null)) {
    return [for (final hit in found) _SubHit(hit.subtype, orphanTone)];
  }
  final withTone = found.where((hit) => hit.rpe != null).length;
  if (withTone == 1 && found.length > 1 && found.last.rpe != null) {
    final tone = found.last.rpe;
    return [for (final hit in found) _SubHit(hit.subtype, tone)];
  }
  return found;
}

String? _subtypeIn(String text) {
  const ordered = [
    'pad work',
    'technique',
    'clinching',
    'sparring',
    'conditioning',
    'tech',
    'pads',
    'clinch',
    'spar',
  ];
  for (final alias in ordered) {
    if (RegExp('\\b${RegExp.escape(alias)}\\b').hasMatch(text)) {
      return _subtypeCanonical[alias];
    }
  }
  return null;
}

int? _intensityIn(String text) {
  final match = RegExp(
    r'\b(easy|light|moderate|hard|heavy|brutal)\b',
  ).firstMatch(text);
  if (match == null) {
    return null;
  }
  return intensityRpe[match.group(1)!];
}

int? _bareIntensity(String text) => _intensityIn(text);

int _unitMinutes(String number, String unit) {
  final value = double.parse(number);
  if (unit.startsWith('h')) {
    return (value * 60).round();
  }
  return value.round();
}

int? _durationMinutes(String text) {
  final re = RegExp(r'\b(\d+(?:\.\d+)?)\s*(minutes|mins|min)\b');
  var total = 0;
  var any = false;
  for (final match in re.allMatches(text)) {
    any = true;
    total += double.parse(match.group(1)!).round();
  }
  return any ? total : null;
}

int? _explicitRpe(String text) {
  final match = RegExp(r'\brpe\s+(\d+(?:\.\d+)?)\b').firstMatch(text);
  if (match == null) {
    return null;
  }
  return double.parse(match.group(1)!).round().clamp(1, 10);
}

int _weightedRpe(List<ParsedBlock> blocks) {
  final minutes = blocks.fold<int>(0, (sum, block) => sum + block.durationMin);
  if (minutes == 0) {
    return 7;
  }
  final load = blocks.fold<double>(0, (sum, block) => sum + block.load);
  return (load / minutes).round();
}

double? _distanceKm(String text) {
  final km = RegExp(r'\b(\d+(?:\.\d+)?)\s*km\b').firstMatch(text);
  if (km != null) {
    return double.parse(km.group(1)!);
  }
  final k = RegExp(r'\b(\d+(?:\.\d+)?)k\b').firstMatch(text);
  if (k != null) {
    return double.parse(k.group(1)!);
  }
  return null;
}

bool _isRun(String text, _ExerciseHit? match) {
  if (RegExp(r'\b(ran|run|running|jog|jogged)\b').hasMatch(text)) {
    return true;
  }
  return match?.exercise.name == 'Run';
}

bool _isHike(String text, _ExerciseHit? match) {
  if (RegExp(r'\bhik(?:e|ed|ing)\b').hasMatch(text)) {
    return true;
  }
  return match?.exercise.name == 'Hike';
}

bool _isYoga(String text, _ExerciseHit? match) {
  if (RegExp(r'\byoga\b').hasMatch(text)) {
    return true;
  }
  return match?.exercise.name == 'Yoga';
}

_ExerciseHit? _matchExercise(List<Exercise> exercises, String text) {
    final exact = <_ExerciseHit>[];
    for (final exercise in exercises) {
      final aliases = [exercise.name, ...exercise.aliases];
      for (final alias in aliases) {
        final pattern = RegExp('\\b${RegExp.escape(alias.toLowerCase())}\\b');
        if (pattern.hasMatch(text)) {
          exact.add(_ExerciseHit(exercise, alias.toLowerCase(), 0));
        }
      }
    }
    if (exact.isNotEmpty) {
      exact.sort((a, b) => b.alias.length.compareTo(a.alias.length));
      return exact.first;
    }

    final words = text
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    _ExerciseHit? best;
    for (var start = 0; start < words.length; start++) {
      for (var length = 1; length <= 4 && start + length <= words.length; length++) {
        final phrase = words.sublist(start, start + length).join(' ');
        if (RegExp(r'\d').hasMatch(phrase)) {
          continue;
        }
        for (final exercise in exercises) {
          final aliases = [exercise.name.toLowerCase(), ...exercise.aliases];
          for (final alias in aliases) {
            final distance = levenshtein(phrase, alias);
            if (distance == 0 || distance > 2) {
              continue;
            }
            final shorter = phrase.length < alias.length
                ? phrase.length
                : alias.length;
            if (shorter <= 4 && distance > 1) {
              continue;
            }
            if (best == null ||
                distance < best.distance ||
                (distance == best.distance && alias.length > best.alias.length)) {
              best = _ExerciseHit(exercise, alias, distance);
            }
          }
        }
      }
    }
    return best;
  }

  _Slots _strengthSlots(String text) {
    int? sets;
    int? reps;
    final setsOf = RegExp(
      r'\b(\d+)\s*sets?\s+of\s+(\d+)\b',
    ).firstMatch(text);
    final by = RegExp(r'\b(\d+)\s*(?:x|×|by)\s*(\d+)\b').firstMatch(text);
    if (setsOf != null) {
      sets = int.parse(setsOf.group(1)!);
      reps = int.parse(setsOf.group(2)!);
    } else if (by != null) {
      sets = int.parse(by.group(1)!);
      reps = int.parse(by.group(2)!);
    }
    double? weight;
    final atKg = RegExp(
      r'\bat\s+(\d+(?:\.\d+)?)\s*kg\b',
    ).firstMatch(text);
    final kg = RegExp(r'\b(\d+(?:\.\d+)?)\s*kg\b').firstMatch(text);
    final suffixed = RegExp(r'\b(\d+(?:\.\d+)?)k\b').firstMatch(text);
    final atBare = RegExp(r'\bat\s+(\d+(?:\.\d+)?)\b').firstMatch(text);
    if (atKg != null) {
      weight = double.parse(atKg.group(1)!);
    } else if (kg != null) {
      weight = double.parse(kg.group(1)!);
    } else if (suffixed != null) {
      weight = double.parse(suffixed.group(1)!);
    } else if (atBare != null) {
      weight = double.parse(atBare.group(1)!);
    }
    final bodyweight = RegExp(r'\bbody\s*weight\b|\bbw\b').hasMatch(text);
    return _Slots(
      sets: sets,
      reps: reps,
      weightKg: weight,
      bodyweight: bodyweight,
    );
  }

List<ParsedSession> _mergeGym(List<ParsedSession> items) {
  final merged = <ParsedSession>[];
  for (final item in items) {
    if (merged.isNotEmpty && item.type == 'gym' && merged.last.type == 'gym') {
      merged.last.sets.addAll(item.sets);
      final previous = merged.last.raw;
      merged.last.raw = '$previous; ${item.raw}';
    } else {
      merged.add(item);
    }
  }
  return merged;
}

String _exerciseFragment(String text) {
  var fragment = text;
  fragment = fragment.replaceAll(
    RegExp(
      r'\b\d+(?:\.\d+)?\s*(?:sets?|reps?|kg|k|minutes|mins|min|hours|hour|km)\b',
    ),
    ' ',
  );
  fragment = fragment.replaceAll(
    RegExp(
      r'\b(?:sets?|of|at|by|x|rpe|bodyweight|body|weight|another|for|minutes|mins|min|and|then)\b',
    ),
    ' ',
  );
  fragment = fragment.replaceAll(RegExp(r'\d+(?:\.\d+)?'), ' ');
  fragment = fragment.replaceAll(RegExp(r'\s+'), ' ').trim();
  return fragment;
}

String _typeLabel(String type) => switch (type) {
  'gym' => 'Gym',
  'muay_thai' => 'Muay Thai',
  'run' => 'Run',
  'hike' => 'Hike',
  'yoga' => 'Yoga',
  _ => 'Other',
};

int levenshtein(String a, String b) {
  if (a == b) {
    return 0;
  }
  if (a.isEmpty) {
    return b.length;
  }
  if (b.isEmpty) {
    return a.length;
  }
  var previous = List<int>.generate(b.length + 1, (index) => index);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final insert = current[j - 1] + 1;
      final delete = previous[j] + 1;
      final replace = previous[j - 1] + cost;
      var best = insert < delete ? insert : delete;
      if (replace < best) {
        best = replace;
      }
      current[j] = best;
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}

bool mentionsSubtype(String text) => _mentionsSubtype(text);
