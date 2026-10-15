import 'filler_cleanup.dart';
import 'voice_end_word.dart';

const poundsToKg = 0.45359237;
const milesToKm = 1.609344;

double roundKg(double value) => (value * 10).round() / 10;

/// Pounds land on a 0.5 kg plate. 100 lb is 45.5 kg.
double roundHalfKg(double value) => (value * 2).round() / 2;

double roundKm(double value) => (value * 100).round() / 100;

String fmtKg(double value) {
  final rounded = roundKg(value);
  if ((rounded - rounded.round()).abs() < 0.001) {
    return rounded.round().toString();
  }
  return rounded.toStringAsFixed(1);
}

String fmtKm(double value) {
  final rounded = roundKm(value);
  if ((rounded - rounded.round()).abs() < 0.001) {
    return rounded.round().toString();
  }
  var text = rounded.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return text;
}

const _ones = {
  'zero': 0,
  'oh': 0,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
};

const _tens = {
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fifty': 50,
  'sixty': 60,
  'seventy': 70,
  'eighty': 80,
  'ninety': 90,
};

String normaliseTranscript(
  String input, {
  Iterable<String> exercises = const [],
}) {
  var text = input.toLowerCase().replaceAll('’', "'").replaceAll('‘', "'");
  text = FillerCleanup.clean(text);
  text = VoiceEndWord.strip(text);
  text = text.replaceAllMapped(
    RegExp(r'(\d)\.(\d)'),
    (match) => '${match.group(1)}§${match.group(2)}',
  );
  text = text.replaceAll(RegExp(r'[.!?]'), ' ; ');
  text = text.replaceAll('§', '.');
  text = _durationIdioms(text);
  text = _numberWords(text);
  text = _durationIdioms(text);
  text = text.replaceAllMapped(
    RegExp(r'\b(\d+)\s+point\s+(\d+)\b'),
    (match) => '${match.group(1)}.${match.group(2)}',
  );
  text = text.replaceAllMapped(RegExp(r'\b(\d+)\s+and\s+a\s+half\b'), (match) {
    return '${match.group(1)}.5';
  });
  text = text.replaceAllMapped(
    RegExp(r'\b(\d+)\s+(x|by)\s+(\d+)\b'),
    (match) => '${match.group(1)}x${match.group(3)}',
  );
  text = _corrections(text, exercises);
  text = _imperial(text);
  text = text.replaceAll(RegExp(r'\bkilograms?\b|\bkilos?\b|\bkgs\b'), 'kg');
  text = text.replaceAll(RegExp(r'\bkilometres?\b|\bkilometers?\b'), 'km');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceAll(RegExp(r'\s+,'), ',');
  text = text.replaceAll(RegExp(r'(?: ;)+$'), '').trim();
  return text;
}

String _corrections(String text, Iterable<String> exercises) {
  final marker = RegExp(r'\b(?:no\s+wait|sorry|i\s+mean|actually)\s+');
  final name = RegExp(
    r'(?:\b(?!and\b|then\b|of\b|at\b|for\b|the\b|a\b)[a-z][a-z-]*\b\s+)*\b(?!and\b|then\b|of\b|at\b|for\b|the\b|a\b)[a-z][a-z-]*\b\s*$',
  );
  final scheme = RegExp(
    r'(?:\b(?:\d+x\d+|\d+(?:\.\d+)?|sets?|reps?|of|at|x|by|for|kg|k)\b\s*)+$',
  );
  final newScheme = RegExp(
    r'^(?:\d+\s*(?:x|by)\s*\d+|\d+x\d+|\d+\s+sets?\s+of\s+\d+|\d+\s+for\s+\d+|\d+\s+reps?\s+\d+\s+sets?|\d+\s+sets?\s+\d+\s+reps?)\b',
  );
  final names = [
    for (final exercise in exercises)
      if (exercise.trim().isNotEmpty) exercise.toLowerCase(),
  ];
  var current = text;
  while (true) {
    final match = marker.firstMatch(current);
    if (match == null) {
      return current;
    }
    var rest = current.substring(match.end);
    var before = current.substring(0, match.start);
    rest = _composeWeightCorrection(before, rest);
    final token = RegExp(r'^(\S+)').firstMatch(rest)?.group(1) ?? '';
    final known = _knownExercise(rest, names);
    if (RegExp(r'^\d+\s*(?:x|by)\s*\d+\b|^\d+x\d+\b').hasMatch(rest)) {
      final weight = RegExp(
        r'\s*(?:\bat\s+\d+(?:\.\d+)?(?:\s*(?:kg|k|kilos?|pounds?|lbs?|lb))?|\d+(?:\.\d+)?\s*(?:kg|k|kilos?|pounds?|lbs?|lb))\s*$',
      ).firstMatch(before);
      var keptWeight = '';
      if (weight != null) {
        keptWeight = before.substring(weight.start).trim();
        before = before.substring(0, weight.start);
      }
      before = '${before.replaceFirst(scheme, '').trim()} $keptWeight'.trim();
    } else if (known != null) {
      final after = rest.substring(known.length).trimLeft();
      if (newScheme.hasMatch(after)) {
        final weight = RegExp(
          r'\s*(?:\bat\s+\d+(?:\.\d+)?(?:\s*(?:kg|k|kilos?|pounds?|lbs?|lb))?|\d+(?:\.\d+)?\s*(?:kg|k|kilos?|pounds?|lbs?|lb))\s*$',
        ).firstMatch(before);
        final afterHasWeight = RegExp(
          r'\b(?:at\s+\d+(?:\.\d+)?|\d+(?:\.\d+)?\s*(?:kg|k|kilos?|pounds?|lbs?|lb))\b',
        ).hasMatch(after);
        var keptWeight = '';
        if (weight != null && !afterHasWeight) {
          keptWeight = before.substring(weight.start).trim();
          before = before.substring(0, weight.start);
        }
        before = before.replaceFirst(scheme, '');
        before = before.replaceFirst(name, '');
        before = '${before.trim()} $keptWeight'.trim();
      } else {
        final tail = scheme.firstMatch(before);
        final head = tail == null ? before : before.substring(0, tail.start);
        final kept = tail == null ? '' : before.substring(tail.start);
        before = '${head.replaceFirst(name, '').trim()} ${kept.trim()}'.trim();
      }
    } else if (RegExp(r'^\d').hasMatch(token)) {
      final removed = RegExp(r'(\S+)\s*$').firstMatch(before)?.group(1) ?? '';
      before = before.replaceFirst(RegExp(r'\S+\s*$'), '');
      if (RegExp(
        r'^(?:kg|k|kilos?|kilograms?|pounds?|lbs?|lb)$',
      ).hasMatch(removed)) {
        before = before.replaceFirst(RegExp(r'\d+(?:\.\d+)?\s*$'), '');
      }
    }
    current = '${before.trim()} ${rest.trim()}'.trim();
  }
}

/// "at 140 no wait 1 50" is still a weight, so the replacement is 150.
String _composeWeightCorrection(String before, String rest) {
  final replacingWeight = RegExp(
    r'(?:\bat\s+\d+(?:\.\d+)?(?:\s*(?:kg|k|kilos?|pounds?|lbs?|lb))?|\d+(?:\.\d+)?\s*(?:kg|k|kilos?|pounds?|lbs?|lb))\s*$',
  ).hasMatch(before);
  if (!replacingWeight) {
    return rest;
  }
  final tens = RegExp(r'^(\d)\s+(\d{2})\b').firstMatch(rest);
  if (tens != null) {
    final lead = int.parse(tens.group(1)!);
    final tail = int.parse(tens.group(2)!);
    if (lead >= 1 && lead <= 9 && tail >= 10 && tail < 100) {
      return '${lead * 100 + tail}${rest.substring(tens.end)}';
    }
  }
  final oh = RegExp(r'^(\d)\s+0\s+(\d)\b').firstMatch(rest);
  if (oh != null) {
    final lead = int.parse(oh.group(1)!);
    final tail = int.parse(oh.group(2)!);
    if (lead >= 1 && lead <= 9 && tail <= 9) {
      return '${lead * 100 + tail}${rest.substring(oh.end)}';
    }
  }
  return rest;
}

String? _knownExercise(String rest, List<String> names) {
  String? best;
  for (final name in names) {
    if (RegExp('^${RegExp.escape(name)}\\b').hasMatch(rest) &&
        (best == null || name.length > best.length)) {
      best = name;
    }
  }
  return best;
}

String _durationIdioms(String text) {
  text = text.replaceAll(
    RegExp(
      r'\b(?:an|a|one|\d+)\s+hours?\s+and\s+a\s+half\b|\bhour\s+and\s+a\s+half\b|\b(?:one|\d+)\s+and\s+a\s+half\s+hours?\b',
    ),
    '90 minutes',
  );
  text = text.replaceAll(
    RegExp(r'\bhalf\s+an?\s+hour\b|\ba\s+half\s+hour\b'),
    '30 minutes',
  );
  text = text.replaceAll(RegExp(r'\b(?:an|a|one)\s+hour\b'), '60 minutes');
  text = text.replaceAllMapped(
    RegExp(
      r'(?<!\bslept\s)(?<!\bsleep\s)\b(\d+(?:\.\d+)?)\s+hours?\b(?!\s+(?:of\s+)?sleep\b)',
    ),
    (m) {
      final hours = double.parse(m.group(1)!);
      return '${(hours * 60).round()} minutes';
    },
  );
  return text;
}

/// Compose a whole integer, including hundreds, before any later "point" fraction.
String _numberWords(String input) {
  final tokens = input.split(RegExp(r'\s+')).where((token) => token.isNotEmpty);
  final pending = tokens.toList();
  final out = <String>[];
  for (var i = 0; i < pending.length; i++) {
    final read = _readInteger(pending, i);
    if (read == null) {
      out.add(pending[i]);
      continue;
    }
    out.add('${read.value}${read.suffix}');
    i += read.consumed - 1;
  }
  return out.join(' ');
}

class _ReadInt {
  const _ReadInt(this.value, this.consumed, this.suffix);

  final int value;
  final int consumed;
  final String suffix;
}

final _wordToken = RegExp(r'^([a-z-]+)([^a-z-]*)$');

({String word, String suffix})? _splitWord(String raw) {
  final match = _wordToken.firstMatch(raw);
  if (match == null) {
    return null;
  }
  return (word: match.group(1)!, suffix: match.group(2)!);
}

_ReadInt? _readInteger(List<String> tokens, int start) {
  final first = _splitWord(tokens[start]);
  if (first == null) {
    return null;
  }
  if ((first.word == 'a' || first.word == 'an') && start + 1 < tokens.length) {
    final hundred = _splitWord(tokens[start + 1]);
    if (hundred != null && hundred.word == 'hundred') {
      return _finishHundred(tokens, start, 100, hundred.suffix);
    }
  }
  final ones = _ones[first.word];
  if (ones != null && ones >= 1 && ones <= 9 && start + 1 < tokens.length) {
    final hundred = _splitWord(tokens[start + 1]);
    if (hundred != null && hundred.word == 'hundred') {
      return _finishHundred(tokens, start, ones * 100, hundred.suffix);
    }
  }
  final plate = _readPlate(tokens, start);
  if (plate != null) {
    return plate;
  }
  return _readUnderHundred(tokens, start);
}

/// "a hundred" / "two hundred" plus an optional remainder under 100.
_ReadInt _finishHundred(List<String> tokens, int start, int hundreds, String hundredSuffix) {
  var value = hundreds;
  var consumed = 2;
  var suffix = hundredSuffix;
  var cursor = start + 2;
  if (cursor < tokens.length) {
    final and = _splitWord(tokens[cursor]);
    if (and != null && and.word == 'and' && and.suffix.isEmpty) {
      final afterAnd = _readUnderHundred(tokens, cursor + 1);
      if (afterAnd != null) {
        cursor += 1;
        value += afterAnd.value;
        return _ReadInt(
          value,
          (cursor - start) + afterAnd.consumed,
          afterAnd.suffix,
        );
      }
    }
  }
  final rest = _readUnderHundred(tokens, cursor);
  if (rest != null) {
    value += rest.value;
    consumed = (cursor - start) + rest.consumed;
    suffix = rest.suffix;
  }
  return _ReadInt(value, consumed, suffix);
}

const _weightUnits = {
  'kg',
  'kgs',
  'kilo',
  'kilos',
  'kilogram',
  'kilograms',
  'pound',
  'pounds',
  'lb',
  'lbs',
};

/// A casual plate ("two twenty", "one oh two") is a weight only when it
/// follows "at" or sits immediately before kg/kilos (optionally "point five").
bool _weightContext(List<String> tokens, int start, int consumed) {
  if (start > 0 && _splitWord(tokens[start - 1])?.word == 'at') {
    return true;
  }
  return _weightUnitFollows(tokens, start + consumed);
}

bool _weightUnitFollows(List<String> tokens, int index) {
  var cursor = index;
  if (cursor < tokens.length) {
    final point = _splitWord(tokens[cursor]);
    if (point != null &&
        point.word == 'point' &&
        point.suffix.isEmpty &&
        cursor + 1 < tokens.length) {
      final fraction = _splitWord(tokens[cursor + 1]);
      if (fraction != null && _ones.containsKey(fraction.word)) {
        cursor += 2;
      }
    }
  }
  if (cursor >= tokens.length) {
    return false;
  }
  final word = _splitWord(tokens[cursor])?.word;
  return word != null && _weightUnits.contains(word);
}

/// Plate speech runs before corrections, and only in a weight.
/// "at one forty" is 140. "two twenty kilos" is 220. "two twenty minutes" is not.
_ReadInt? _readPlate(List<String> tokens, int start) {
  final shaped = _plateShape(tokens, start);
  if (shaped == null || !_weightContext(tokens, start, shaped.consumed)) {
    return null;
  }
  return shaped;
}

_ReadInt? _plateShape(List<String> tokens, int start) {
  final first = _splitWord(tokens[start]);
  if (first == null) {
    return null;
  }
  final lead = _ones[first.word];
  if (lead == null || lead < 1 || lead > 9) {
    return null;
  }
  if (start + 2 < tokens.length) {
    final mid = _splitWord(tokens[start + 1]);
    final last = _splitWord(tokens[start + 2]);
    if (mid != null &&
        mid.word == 'oh' &&
        mid.suffix.isEmpty &&
        last != null &&
        _ones.containsKey(last.word) &&
        _ones[last.word]! <= 9) {
      return _ReadInt(lead * 100 + _ones[last.word]!, 3, last.suffix);
    }
  }
  final rest = _readUnderHundred(tokens, start + 1);
  if (rest != null && rest.value >= 10 && rest.value < 100) {
    return _ReadInt(lead * 100 + rest.value, 1 + rest.consumed, rest.suffix);
  }
  return null;
}

_ReadInt? _readUnderHundred(List<String> tokens, int start) {
  if (start >= tokens.length) {
    return null;
  }
  final first = _splitWord(tokens[start]);
  if (first == null) {
    return null;
  }
  if (first.word.contains('-')) {
    final bits = first.word.split('-');
    if (bits.length == 2 &&
        _tens.containsKey(bits[0]) &&
        _ones.containsKey(bits[1]) &&
        _ones[bits[1]]! < 10) {
      return _ReadInt(_tens[bits[0]]! + _ones[bits[1]]!, 1, first.suffix);
    }
  }
  if (_tens.containsKey(first.word) && start + 1 < tokens.length) {
    final next = _splitWord(tokens[start + 1]);
    if (next != null && _ones.containsKey(next.word) && _ones[next.word]! < 10) {
      return _ReadInt(
        _tens[first.word]! + _ones[next.word]!,
        2,
        next.suffix,
      );
    }
  }
  if (_ones.containsKey(first.word)) {
    return _ReadInt(_ones[first.word]!, 1, first.suffix);
  }
  if (_tens.containsKey(first.word)) {
    return _ReadInt(_tens[first.word]!, 1, first.suffix);
  }
  return null;
}

String _imperial(String text) {
  text = text.replaceAllMapped(
    RegExp(r'\b(\d+(?:\.\d+)?)\s*(?:lbs?|pounds?)\b'),
    (m) => '${fmtKg(roundHalfKg(double.parse(m.group(1)!) * poundsToKg))} kg',
  );
  text = text.replaceAllMapped(
    RegExp(r'\b(\d+(?:\.\d+)?)\s*(?:miles?|mi)\b'),
    (m) => '${fmtKm(double.parse(m.group(1)!) * milesToKm)} km',
  );
  return text;
}
