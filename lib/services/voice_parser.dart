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
    this.rir,
    this.rirLastOnly = false,
    this.rirFlagged = false,
    this.rirSetIndex,
    this.lightBar = false,
    this.ambiguous = false,
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
  int? rir;
  bool rirLastOnly;
  bool rirFlagged;
  int? rirSetIndex;
  bool lightBar;
  bool ambiguous;

  String get summary {
    final name = unmatched || exerciseName == null ? '?' : exerciseName!;
    if (ambiguous) {
      return name == '?' ? '?' : '$name · ?';
    }
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
    this.spoken,
  });

  String subtype;
  int? durationMin;
  int rpe;
  String? spoken;

  double get load => (durationMin ?? 0) * rpe.toDouble();

  String get label {
    final name = spoken;
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return switch (subtype) {
      'technique' => 'Technique',
      'pads' => 'Pads',
      'clinch' => 'Clinch',
      'sparring' => 'Sparring',
      'conditioning' => 'Conditioning',
      'other' => 'Other',
      _ => subtype,
    };
  }

  String get summary {
    final time = durationMin == null ? '?' : '$durationMin min';
    if (durationMin == null) {
      return '$label · $time · RPE $rpe';
    }
    return '$label · $time · RPE $rpe · ${load.round()}';
  }
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
    this.ambiguous = false,
  }) : sets = sets ?? <ParsedSet>[],
       blocks = blocks ?? <ParsedBlock>[];

  String type;
  int? durationMin;
  int? rpe;
  double? distanceKm;
  bool ambiguous;
  final List<ParsedSet> sets;
  final List<ParsedBlock> blocks;
  String raw;

  String get summary {
    if (ambiguous && sets.isEmpty) {
      return '${_typeLabel(type)} · ?';
    }
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
    this.imperial = false,
  });

  final String normalised;
  final List<ParsedSession> sessions;
  final List<ParsedPlan> plans;
  final bool imperial;

  int get entryCount => sessions.fold<int>(
    0,
    (sum, session) => sum + (session.sets.isEmpty ? 1 : session.sets.length),
  );
}

class VoiceParser {
  VoiceParser(this.exercises, {this.roundMinutes = 3});

  final List<Exercise> exercises;
  final int roundMinutes;

  factory VoiceParser.seeded() => VoiceParser(seedExercises());

  ParseResult parse(String input, {Exercise? lastExercise}) {
    final spoken = input.trim();
    final imperial = RegExp(
      r'\b(?:lbs?|pounds?|miles?|mi)\b',
      caseSensitive: false,
    ).hasMatch(spoken);
    final names = <String>[
      for (final exercise in exercises) ...[
        exercise.name,
        ...exercise.aliases,
      ],
    ];
    final normalised = normaliseTranscript(spoken, exercises: names);
    if (_hasWeekday(normalised)) {
      return ParseResult(
        normalised: normalised,
        sessions: const [],
        plans: _parsePlans(normalised),
        imperial: imperial,
      );
    }
    final parts = _splitEntries(normalised);
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
    final sessions = _mergeGym(parsed);
    for (final session in sessions) {
      session.raw = spoken;
    }
    return ParseResult(
      normalised: normalised,
      sessions: sessions,
      plans: const [],
      imperial: imperial,
    );
  }

  ParsedSession _parseEntry(String text, Exercise? lastExercise) {
    final durationAmbiguous = _ambiguousAmount(
      text,
      'minutes|mins|min|hours|hour|hrs|hr',
    );
    final distanceAmbiguous = _ambiguousAmount(text, 'km|k');
    final ambiguous = durationAmbiguous || distanceAmbiguous;
    final stated = durationAmbiguous ? null : _durationMinutes(text);
    final distance = distanceAmbiguous ? null : _distanceKm(text);
    final blocks = _parseBlocks(text);
    final product = _roundProduct(text);
    if (blocks.isNotEmpty || _mentionsThai(text) || product != null) {
      final statedDuration = stated;
      if (product == null) {
        _balanceBlocks(blocks, stated);
      }
      final thai =
          _mentionsThai(text) ||
          product != null ||
          blocks.any((block) => block.subtype != 'other');
      final explicit = _explicitRpe(text);
      final weighted = blocks.isEmpty ? null : _weightedRpe(blocks);
      final minutes = blocks.isEmpty
          ? (product ?? statedDuration)
          : _sessionMinutes(blocks, statedDuration);
      return ParsedSession(
        type: thai ? 'muay_thai' : 'other',
        durationMin: minutes,
        rpe: explicit ?? weighted ?? _bareIntensity(text),
        blocks: blocks,
        raw: text,
        ambiguous: ambiguous,
      );
    }

    final match = _matchExercise(exercises, text);
    if (_isRun(text, match)) {
      return ParsedSession(
        type: 'run',
        durationMin: stated,
        rpe: _explicitRpe(text) ?? _bareIntensity(text),
        distanceKm: distance,
        raw: text,
        ambiguous: ambiguous,
      );
    }
    if (_isHike(text, match)) {
      return ParsedSession(
        type: 'hike',
        durationMin: stated,
        rpe: _explicitRpe(text) ?? _bareIntensity(text),
        distanceKm: distance,
        raw: text,
        ambiguous: ambiguous,
      );
    }
    if (_isYoga(text, match)) {
      return ParsedSession(
        type: 'yoga',
        durationMin: stated,
        rpe: _explicitRpe(text) ?? _bareIntensity(text),
        raw: text,
        ambiguous: ambiguous,
      );
    }

    if (match != null &&
        match.exercise.category == 'cardio' &&
        match.exercise.name != 'Run' &&
        match.exercise.name != 'Hike') {
      return ParsedSession(
        type: 'other',
        durationMin: stated,
        rpe: _explicitRpe(text) ?? _bareIntensity(text),
        distanceKm: distance,
        raw: text,
        ambiguous: ambiguous,
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
        durationMin: stated,
        rpe: _explicitRpe(text) ?? _bareIntensity(text),
        raw: text,
        ambiguous: ambiguous,
      );
    }

    final slots = _strengthSlots(text);
    final stray = _strayDigits(text);
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

    final heard = liftRir(text);
    final named = heard.setIndex;
    final outOfRange = named != null &&
        slots.sets != null &&
        (named < 0 || named >= slots.sets!);
    return ParsedSession(
      type: 'gym',
      raw: text,
      sets: [
        ParsedSet(
          exerciseId: exercise?.id,
          exerciseName: exercise?.name,
          spoken: spoken,
          sets: stray ? null : slots.sets,
          reps: stray ? null : slots.reps,
          weightKg: stray ? null : slots.weightKg,
          bodyweight: stray ? false : slots.bodyweight,
          unmatched: unmatched,
          muscleGroups: exercise?.muscleGroups ?? const [],
          category: exercise?.category,
          rir: stray ? null : heard.value,
          rirLastOnly: stray || outOfRange ? false : heard.lastOnly,
          rirFlagged: stray ? false : heard.flagged || outOfRange,
          rirSetIndex: stray ? null : named,
          lightBar: stray
              ? false
              : _lightBarbell(
                  exercise?.name,
                  slots.weightKg,
                  slots.bodyweight,
                ),
          ambiguous: stray,
        ),
      ],
    );
  }

  List<ParsedBlock> _parseBlocks(String text) {
    final blocks = <ParsedBlock>[];
    final consumed = List<bool>.filled(text.length, false);
    final sessionTone = _bareIntensity(text);
    final subtypeAlt =
        'technique|tech|pad work|pads|clinching|clinch|sparring|spar|conditioning';
    final tone = 'easy|light|moderate|hard|heavy|brutal';
    final subList =
        '((?:$subtypeAlt)(?:\\s+(?:$tone))?(?:\\s+(?:and|plus|,)\\s+(?:$subtypeAlt)(?:\\s+(?:$tone))?)*)';
    final unit = 'hours|hour|hrs|hr|minutes|mins|min';

    void take(Match match) {
      for (var i = match.start; i < match.end; i++) {
        if (i >= 0 && i < consumed.length) {
          consumed[i] = true;
        }
      }
    }

    bool free(Match match) {
      for (var i = match.start; i < match.end; i++) {
        if (i < consumed.length && consumed[i]) {
          return false;
        }
      }
      return true;
    }

    void addSubs(List<_SubHit> subs, int minutes) {
      if (subs.isEmpty) {
        return;
      }
      final shares = splitMinutes(minutes, subs.length);
      for (var i = 0; i < subs.length; i++) {
        blocks.add(
          ParsedBlock(
            subtype: subs[i].subtype,
            durationMin: shares[i],
            rpe: subs[i].rpe ?? sessionTone ?? thaiBlockRpe[subs[i].subtype] ?? 6,
          ),
        );
      }
    }

    final ofRe = RegExp(
      '(\\d+(?:\\.\\d+)?)\\s*($unit)\\s+of\\s+(.+?)(?=(?:\\s+and\\s+)?\\d+(?:\\.\\d+)?\\s*(?:$unit)\\s+of\\b|\$)',
    );
    for (final match in ofRe.allMatches(text)) {
      if (!free(match)) {
        continue;
      }
      final subs = _subtypeChunk(match.group(3)!);
      if (subs.isEmpty) {
        continue;
      }
      take(match);
      addSubs(subs, _unitMinutes(match.group(1)!, match.group(2)!));
    }

    final timedRoundsRe = RegExp(
      '\\b(?:($subtypeAlt)\\s+)?(\\d+)\\s+rounds?\\s+of\\s+(\\d+(?:\\.\\d+)?)\\s*($unit)\\b(?:\\s+($subtypeAlt))?',
    );
    for (final match in timedRoundsRe.allMatches(text)) {
      if (!free(match)) {
        continue;
      }
      final name = match.group(1) ?? match.group(5);
      take(match);
      if (name == null) {
        continue;
      }
      final subtype = _subtypeCanonical[name];
      if (subtype == null) {
        continue;
      }
      final count = int.parse(match.group(2)!);
      final minutes = count * _unitMinutes(match.group(3)!, match.group(4)!);
      blocks.add(
        ParsedBlock(
          subtype: subtype,
          durationMin: minutes,
          rpe: sessionTone ?? thaiBlockRpe[subtype] ?? 6,
        ),
      );
    }

    final roundsRe = RegExp(
      '\\b(?:($subtypeAlt)\\s+(\\d+)\\s+rounds?\\b|(\\d+)\\s+rounds?\\s+(?:of\\s+)?($subtypeAlt)\\b)',
    );
    for (final match in roundsRe.allMatches(text)) {
      if (!free(match)) {
        continue;
      }
      final name = match.group(1) ?? match.group(4);
      final count = int.parse(match.group(2) ?? match.group(3)!);
      final subtype = _subtypeCanonical[name];
      if (subtype == null) {
        continue;
      }
      take(match);
      final perRound = roundMinutes < 1 ? 3 : roundMinutes;
      blocks.add(
        ParsedBlock(
          subtype: subtype,
          durationMin: count * perRound,
          rpe: sessionTone ?? thaiBlockRpe[subtype] ?? 6,
        ),
      );
    }

    final forRe = RegExp(
      '$subList\\s+(?:for\\s+)?(\\d+(?:\\.\\d+)?)\\s*($unit)\\b',
    );
    for (final match in forRe.allMatches(text)) {
      if (!free(match)) {
        continue;
      }
      final subs = _subtypeChunk(match.group(1)!);
      if (subs.isEmpty) {
        continue;
      }
      take(match);
      addSubs(subs, _unitMinutes(match.group(2)!, match.group(3)!));
    }

    final leadRe = RegExp(
      '(\\d+(?:\\.\\d+)?)\\s*($unit)\\s+$subList\\b',
    );
    for (final match in leadRe.allMatches(text)) {
      if (!free(match)) {
        continue;
      }
      final subs = _subtypeChunk(match.group(3)!);
      if (subs.isEmpty) {
        continue;
      }
      take(match);
      addSubs(subs, _unitMinutes(match.group(1)!, match.group(2)!));
    }

    final unknownRe = RegExp(
      '\\b([a-z][a-z][a-z]+)\\s+(\\d+(?:\\.\\d+)?)\\s*($unit)\\b',
    );
    for (final match in unknownRe.allMatches(text)) {
      if (!free(match)) {
        continue;
      }
      final word = match.group(1)!;
      if (_subtypeIn(word) != null || _blockedActivity(word)) {
        continue;
      }
      if (_hasExactExercise(exercises, word)) {
        continue;
      }
      take(match);
      final minutes = _unitMinutes(match.group(2)!, match.group(3)!);
      blocks.add(
        ParsedBlock(
          subtype: 'other',
          durationMin: minutes,
          rpe: sessionTone ?? 6,
          spoken: _titleWord(word),
        ),
      );
    }

    final rest = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (!consumed[i]) {
        rest.write(text[i]);
      }
    }
    final leftover = rest.toString().trim();
    if (_mentionsSubtype(leftover)) {
      final subs = _subtypeChunk(leftover);
      for (final sub in subs) {
        blocks.add(
          ParsedBlock(
            subtype: sub.subtype,
            durationMin: null,
            rpe: sub.rpe ?? sessionTone ?? thaiBlockRpe[sub.subtype] ?? 6,
          ),
        );
      }
    }
    return blocks;
  }

  List<String> _splitEntries(String text) {
    final coarse = text.split(RegExp(r'\s*(?:;|,)\s*'));
    final glued = <String>[];
    for (final piece in coarse) {
      final bit = piece.trim();
      if (bit.isEmpty) {
        continue;
      }
      if (glued.isNotEmpty && _isContinuation(bit)) {
        glued[glued.length - 1] = '${glued.last}, $bit';
      } else {
        glued.add(bit);
      }
    }
    final parts = <String>[];
    for (final piece in glued) {
      parts.addAll(_splitConnectors(piece));
    }
    return parts;
  }

  List<String> _splitConnectors(String text) {
    if (_keepTogether(text)) {
      return [text];
    }
    final bits = text.split(RegExp(r'\s+(?:and then|then|and)\s+'));
    if (bits.length == 1) {
      return [text];
    }
    final parts = <String>[];
    for (final bit in bits) {
      final trimmed = bit.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (parts.isNotEmpty && _isContinuation(trimmed)) {
        parts[parts.length - 1] = '${parts.last} and $trimmed';
      } else {
        parts.add(trimmed);
      }
    }
    return parts;
  }

  bool _keepTogether(String text) {
    final thaiLike = _mentionsThai(text) || _mentionsSubtype(text);
    if (!thaiLike) {
      return false;
    }
    if (_hasForeignExercise(text) || _activityWord(text)) {
      return false;
    }
    return true;
  }

  bool _startsEntry(String text) {
    if (_mentionsThai(text) || _mentionsSubtype(text) || _activityWord(text)) {
      return true;
    }
    if (_hasExactExercise(exercises, text)) {
      return true;
    }
    return _unknownTimed(text);
  }

  bool _isContinuation(String text) {
    if (_startsEntry(text)) {
      return false;
    }
    final stripped = text
        .replaceAll(
          RegExp(
            r'\b(?:\d+(?:\.\d+)?|sets?|reps?|of|at|by|x|for|kg|k|km|rpe|rir|minutes|mins|min|hours|hour|hrs|hr|easy|hard|heavy|light|moderate|brutal|comfortable|failure|failed|nearly|near|left|to|two|one|bodyweight|body|weight|bw|and|but|a|half|in|with|the|not|paused|felt)\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    return stripped.isEmpty;
  }

  bool _hasForeignExercise(String text) {
    for (final exercise in exercises) {
      if (exercise.name == 'Muay Thai') {
        continue;
      }
      final aliases = [exercise.name, ...exercise.aliases];
      for (final alias in aliases) {
        final pattern = RegExp('\\b${RegExp.escape(alias.toLowerCase())}\\b');
        if (pattern.hasMatch(text)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _unknownTimed(String text) {
    final match = RegExp(
      r'\b([a-z][a-z][a-z]+)\s+\d+(?:\.\d+)?\s*(?:hours|hour|hrs|hr|minutes|mins|min)\b',
    ).firstMatch(text);
    if (match == null) {
      return false;
    }
    final word = match.group(1)!;
    if (_subtypeIn(word) != null || _blockedActivity(word)) {
      return false;
    }
    return !_hasExactExercise(exercises, word);
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

bool _ambiguousAmount(String text, String units) {
  return RegExp(
    '\\b\\d+(?:\\.\\d+)?(?:\\s+\\d+(?:\\.\\d+)?)+\\s*(?:$units)\\b',
  ).hasMatch(text);
}

/// A second number that the scheme and the weight did not use.
bool _strayDigits(String text) {
  var rest = text;
  rest = rest.replaceAll(RegExp(r'\brpe\s+\d+(?:\.\d+)?\b'), ' ');
  rest = rest.replaceAll(RegExp(r'\brir\s+\d+(?:\.\d+)?\b'), ' ');
  rest = rest.replaceAll(RegExp(r'\b\d+(?:\.\d+)?\s+left\b'), ' ');
  rest = rest.replaceAll(RegExp(r'\bon\s+(?:the\s+)?set\s+\d+\b'), ' ');
  rest = rest.replaceAll(
    RegExp(
      r'\b(?:first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth)\s+set\b',
    ),
    ' ',
  );
  rest = rest.replaceAll(RegExp(r'\b\d+\s*sets?\s+of\s+\d+\b'), ' ');
  rest = rest.replaceAll(RegExp(r'\b\d+\s+reps?\s+\d+\s+sets?\b'), ' ');
  rest = rest.replaceAll(RegExp(r'\b\d+\s+sets?\s+\d+\s+reps?\b'), ' ');
  rest = rest.replaceAll(RegExp(r'\b\d+\s+for\s+\d+\b'), ' ');
  rest = rest.replaceFirst(
    RegExp(r'\b\d+\s*(?:x|×|by)\s*\d+\s+\d+(?:\.\d+)?\b'),
    ' ',
  );
  rest = rest.replaceAll(RegExp(r'\b\d+\s*(?:x|×|by)\s*\d+\b'), ' ');
  rest = rest.replaceAll(RegExp(r'\bat\s+\d+(?:\.\d+)?(?:\s*kg)?\b'), ' ');
  rest = rest.replaceAll(RegExp(r'\b\d+(?:\.\d+)?\s*kg\b'), ' ');
  rest = rest.replaceAll(RegExp(r'\b\d+(?:\.\d+)?\s*k\b'), ' ');
  return RegExp(r'\d').hasMatch(rest);
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

int? _weightedRpe(List<ParsedBlock> blocks) {
  final timed = [
    for (final block in blocks)
      if (block.durationMin != null) block,
  ];
  if (timed.isEmpty) {
    return null;
  }
  final minutes = timed.fold<int>(0, (sum, block) => sum + block.durationMin!);
  if (minutes == 0) {
    return null;
  }
  final load = timed.fold<double>(0, (sum, block) => sum + block.load);
  return (load / minutes).round();
}

void _balanceBlocks(List<ParsedBlock> blocks, int? stated) {
  final missing = [
    for (final block in blocks)
      if (block.durationMin == null) block,
  ];
  if (missing.isEmpty || stated == null || stated <= 0) {
    return;
  }
  final known = blocks.fold<int>(0, (sum, block) => sum + (block.durationMin ?? 0));
  final pool = stated - known;
  if (pool <= 0) {
    return;
  }
  final shares = splitMinutes(pool, missing.length);
  for (var i = 0; i < missing.length; i++) {
    if (shares[i] > 0) {
      missing[i].durationMin = shares[i];
    }
  }
}

int? _roundProduct(String text) {
  final match = RegExp(
    r'\b(\d+)\s+rounds?\s+of\s+(\d+(?:\.\d+)?)\s*(hours|hour|hrs|hr|minutes|mins|min)\b',
  ).firstMatch(text);
  if (match == null) {
    return null;
  }
  return int.parse(match.group(1)!) *
      _unitMinutes(match.group(2)!, match.group(3)!);
}

int? _sessionMinutes(List<ParsedBlock> blocks, int? stated) {
  if (blocks.isEmpty) {
    return stated;
  }
  if (blocks.any((block) => block.durationMin == null)) {
    return null;
  }
  return blocks.fold<int>(0, (sum, block) => sum + block.durationMin!);
}

double? _distanceKm(String text) {
  final km = RegExp(r'\b(\d+(?:\.\d+)?)\s*km\b').firstMatch(text);
  if (km != null) {
    return double.parse(km.group(1)!);
  }
  final k = RegExp(r'\b(\d+(?:\.\d+)?)\s*k\b').firstMatch(text);
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
    final repsThenSets = RegExp(
      r'\b(\d+)\s+reps?\s+(\d+)\s+sets?\b',
    ).firstMatch(text);
    final setsThenReps = RegExp(
      r'\b(\d+)\s+sets?\s+(\d+)\s+reps?\b',
    ).firstMatch(text);
    final forSets = RegExp(r'\b(\d+)\s+for\s+(\d+)\b').firstMatch(text);
    final by = RegExp(r'\b(\d+)\s*(?:x|×|by)\s*(\d+)\b').firstMatch(text);
    if (setsOf != null) {
      sets = int.parse(setsOf.group(1)!);
      reps = int.parse(setsOf.group(2)!);
    } else if (repsThenSets != null) {
      reps = int.parse(repsThenSets.group(1)!);
      sets = int.parse(repsThenSets.group(2)!);
    } else if (setsThenReps != null) {
      sets = int.parse(setsThenReps.group(1)!);
      reps = int.parse(setsThenReps.group(2)!);
    } else if (forSets != null) {
      sets = int.parse(forSets.group(1)!);
      reps = int.parse(forSets.group(2)!);
    } else if (by != null) {
      sets = int.parse(by.group(1)!);
      reps = int.parse(by.group(2)!);
    }
    double? weight;
    final atKg = RegExp(
      r'\bat\s+(\d+(?:\.\d+)?)\s*kg\b',
    ).firstMatch(text);
    final kg = RegExp(r'\b(\d+(?:\.\d+)?)\s*kg\b').firstMatch(text);
    final suffixed = RegExp(r'\b(\d+(?:\.\d+)?)\s*k\b').firstMatch(text);
    final atBare = RegExp(r'\bat\s+(\d+(?:\.\d+)?)\b').firstMatch(text);
    if (atKg != null) {
      weight = double.parse(atKg.group(1)!);
    } else if (kg != null) {
      weight = double.parse(kg.group(1)!);
    } else if (suffixed != null) {
      weight = double.parse(suffixed.group(1)!);
    } else if (atBare != null) {
      weight = double.parse(atBare.group(1)!);
    } else if (by != null) {
      final bare = RegExp(
        r'\b\d+\s*(?:x|×|by)\s*\d+\s+(\d+(?:\.\d+)?)\b',
      ).firstMatch(text);
      if (bare != null) {
        weight = double.parse(bare.group(1)!);
      }
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

bool _hasExactExercise(List<Exercise> exercises, String text) {
  for (final exercise in exercises) {
    final aliases = [exercise.name, ...exercise.aliases];
    for (final alias in aliases) {
      final pattern = RegExp('\\b${RegExp.escape(alias.toLowerCase())}\\b');
      if (pattern.hasMatch(text)) {
        return true;
      }
    }
  }
  return false;
}

bool _blockedActivity(String word) {
  return RegExp(
    r'^(?:yoga|run|ran|running|jog|jogged|hike|hiked|hiking|gym|minutes|minute|mins|min|hours|hour|hrs|hr)$',
  ).hasMatch(word);
}

bool _activityWord(String text) {
  return RegExp(
    r'\b(?:ran|run|running|jog|jogged|hike|hiked|hiking|yoga)\b',
  ).hasMatch(text);
}

String _titleWord(String word) {
  if (word.isEmpty) {
    return word;
  }
  return '${word[0].toUpperCase()}${word.substring(1)}';
}

class LiftRir {
  const LiftRir({
    this.value,
    this.flagged = false,
    this.lastOnly = false,
    this.setIndex,
  });

  final int? value;
  final bool flagged;
  final bool lastOnly;

  /// Zero-based set when failure named one, such as the first set or set 2.
  final int? setIndex;
}

/// Reps in reserve for one lift line.
///
/// Decimals round down (`1.5` → `1`; RPE `8.5` is `10 - 8.5` = `1.5` → `1`) so a fraction
/// never becomes a step-up. RIR outside 0–5, and RPE outside 5–10, come back null and flagged.
/// A negation within the four words before a phrase is also null and flagged. That includes
/// `not`, `hardly`, `barely`, and any word ending in n't (`wasn't`, `didn't`, `isn't`, `wasnt`).
/// Failure with no set number applies to the last set. `failed on the first set` and
/// `failed on set 2` apply to that set. A set number past the logged sets stays flagged
/// and is not moved onto the last set.
LiftRir liftRir(String text) {
  final explicit = RegExp(r'\brir\s+(\d+(?:\.\d+)?)\b').firstMatch(text);
  if (explicit != null) {
    if (_rirNegated(text, explicit.start)) {
      return const LiftRir(flagged: true);
    }
    return _acceptRir(double.parse(explicit.group(1)!));
  }
  final rpe = RegExp(r'\brpe\s+(\d+(?:\.\d+)?)\b').firstMatch(text);
  if (rpe != null) {
    if (_rirNegated(text, rpe.start)) {
      return const LiftRir(flagged: true);
    }
    final value = double.parse(rpe.group(1)!);
    if (value < 5 || value > 10) {
      return const LiftRir(flagged: true);
    }
    return _acceptRir(10 - value);
  }
  final phrases = <(RegExp, int, bool)>[
    (
      RegExp(r'\b(?:near\s+failure|nearly\s+failed|one\s+left|1\s+left)\b'),
      1,
      false,
    ),
    (RegExp(r'\b(?:to\s+failure|failed)\b'), 0, true),
    (RegExp(r'\b(?:two\s+left|2\s+left)\b'), 2, false),
    (RegExp(r'\b(?:easy|comfortable)\b'), 3, false),
  ];
  for (final phrase in phrases) {
    final match = phrase.$1.firstMatch(text);
    if (match == null) {
      continue;
    }
    if (_rirNegated(text, match.start)) {
      return const LiftRir(flagged: true);
    }
    if (phrase.$3) {
      final named = _namedSet(text);
      if (named != null) {
        return LiftRir(value: 0, setIndex: named);
      }
    }
    return LiftRir(value: phrase.$2, lastOnly: phrase.$3);
  }
  return const LiftRir();
}

LiftRir _acceptRir(double raw) {
  final rounded = raw.floor();
  if (rounded < 0 || rounded > 5) {
    return const LiftRir(flagged: true);
  }
  return LiftRir(value: rounded);
}

const _ordinalSet = {
  'first': 0,
  'second': 1,
  'third': 2,
  'fourth': 3,
  'fifth': 4,
  'sixth': 5,
  'seventh': 6,
  'eighth': 7,
  'ninth': 8,
  'tenth': 9,
};

int? _namedSet(String text) {
  final numbered = RegExp(r'\bon\s+(?:the\s+)?set\s+(\d+)\b').firstMatch(text);
  if (numbered != null) {
    final number = int.parse(numbered.group(1)!);
    if (number < 1) {
      return -1;
    }
    return number - 1;
  }
  final ordinal = RegExp(
    r'\b(?:on\s+)?(?:the\s+)?(first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth)\s+set\b',
  ).firstMatch(text);
  if (ordinal != null) {
    return _ordinalSet[ordinal.group(1)];
  }
  return null;
}

const _barbellLifts = {
  'Bench press',
  'Incline bench press',
  'Close-grip bench press',
  'Overhead press',
  'Back squat',
  'Front squat',
  'Deadlift',
  'Sumo deadlift',
  'Romanian deadlift',
  'Rack pull',
  'Good morning',
  'Barbell row',
  'Pendlay row',
  'Hip thrust',
  'Power clean',
  'Hang clean',
  'Snatch',
};

bool _lightBarbell(String? name, double? weightKg, bool bodyweight) {
  if (name == null || weightKg == null || bodyweight) {
    return false;
  }
  return weightKg < 20 && _barbellLifts.contains(name);
}

bool _rirNegated(String text, int index) {
  final prior = text.substring(0, index).trim();
  if (prior.isEmpty) {
    return false;
  }
  final words = prior.split(RegExp(r'\s+'));
  final start = words.length > 4 ? words.length - 4 : 0;
  for (var i = words.length - 1; i >= start; i--) {
    final raw = words[i];
    if (raw == 'but' || raw.contains(',')) {
      break;
    }
    final word = raw.replaceAll(RegExp(r"[^a-z']"), '');
    if (_rirNegationWord(word)) {
      return true;
    }
  }
  return false;
}

bool _rirNegationWord(String word) {
  if (word.endsWith("n't")) {
    return true;
  }
  if (RegExp(
    r"^(?:was|were|is|are|did|does|do|had|has|have|would|could|should|must|need|ai|wo|ca)nt$",
  ).hasMatch(word)) {
    return true;
  }
  const words = {'not', 'nowhere', 'never', 'no', 'hardly', 'barely'};
  return words.contains(word);
}

ParseResult sessionToParseResult(Session session) {
  double? distance;
  for (final set in session.sets) {
    if (set.distanceKm != null) {
      distance = set.distanceKm;
      break;
    }
  }
  return ParseResult(
    normalised: session.rawTranscript ?? '',
    plans: const [],
    sessions: [
      ParsedSession(
        type: session.type,
        durationMin: session.durationMin,
        rpe: session.rpe,
        distanceKm: distance,
        raw: session.rawTranscript ?? '',
        sets: [
          if (session.type == 'gym')
            for (final set in session.sets)
              ParsedSet(
                exerciseId: set.exerciseId,
                exerciseName: set.exerciseName,
                sets: set.setCount,
                reps: set.reps,
                weightKg: set.weightKg,
                bodyweight: set.bodyweight,
                unmatched: set.exerciseId == null,
                muscleGroups: set.muscleGroups,
                rir: set.rir,
              ),
        ],
        blocks: [
          for (final block in session.blocks)
            ParsedBlock(
              subtype: block.subtype,
              durationMin: block.durationMin,
              rpe: block.rpe,
              spoken: block.label,
            ),
        ],
      ),
    ],
  );
}
