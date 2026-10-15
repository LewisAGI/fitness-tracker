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

String normaliseTranscript(String input) {
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
  text = _corrections(text);
  text = _imperial(text);
  text = text.replaceAll(RegExp(r'\bkilograms?\b|\bkilos?\b|\bkgs\b'), 'kg');
  text = text.replaceAll(RegExp(r'\bkilometres?\b|\bkilometers?\b'), 'km');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceAll(RegExp(r'\s+,'), ',');
  text = text.replaceAll(RegExp(r'(?: ;)+$'), '').trim();
  return text;
}

String _corrections(String text) {
  final marker = RegExp(r'\b(?:no\s+wait|sorry|i\s+mean|actually)\s+');
  final name = RegExp(
    r'(?:\b(?!and\b|then\b|of\b|at\b|for\b|the\b|a\b)[a-z][a-z-]*\b\s+)*\b(?!and\b|then\b|of\b|at\b|for\b|the\b|a\b)[a-z][a-z-]*\b\s*$',
  );
  final scheme = RegExp(
    r'(?:\b(?:\d+x\d+|\d+(?:\.\d+)?|sets?|reps?|of|at|x|by|for|kg|k)\b\s*)+$',
  );
  var current = text;
  while (true) {
    final match = marker.firstMatch(current);
    if (match == null) {
      return current;
    }
    final rest = current.substring(match.end);
    final token = RegExp(r'^(\S+)').firstMatch(rest)?.group(1) ?? '';
    var before = current.substring(0, match.start);
    if (RegExp(r'^\d+x\d+\b').hasMatch(rest)) {
      final weight = RegExp(
        r'\s*(?:\bat\s+\d+(?:\.\d+)?(?:\s*(?:kg|k|kilos?|pounds?|lbs?|lb))?|\d+(?:\.\d+)?\s*(?:kg|k|kilos?|pounds?|lbs?|lb))\s*$',
      ).firstMatch(before);
      var keptWeight = '';
      if (weight != null) {
        keptWeight = before.substring(weight.start).trim();
        before = before.substring(0, weight.start);
      }
      before = '${before.replaceFirst(scheme, '').trim()} $keptWeight'.trim();
    } else if (RegExp(r'^[a-z]').hasMatch(token)) {
      final tail = scheme.firstMatch(before);
      final head = tail == null ? before : before.substring(0, tail.start);
      final kept = tail == null ? '' : before.substring(tail.start);
      before = '${head.replaceFirst(name, '').trim()} ${kept.trim()}'.trim();
    } else {
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
  'k',
  'kilo',
  'kilos',
  'kilogram',
  'kilograms',
  'pound',
  'pounds',
  'lb',
  'lbs',
  'point',
};

bool _weightContext(List<String> tokens, int start) {
  if (start > 0) {
    final previous = _splitWord(tokens[start - 1])?.word;
    if (previous == 'at') {
      return true;
    }
  }
  for (var i = start; i < tokens.length && i < start + 8; i++) {
    final word = _splitWord(tokens[i])?.word;
    if (word != null && _weightUnits.contains(word)) {
      return true;
    }
  }
  return false;
}

/// Plate speech: "one oh two" is 102, "two twenty" is 220. Only in a weight.
_ReadInt? _readPlate(List<String> tokens, int start) {
  if (!_weightContext(tokens, start)) {
    return null;
  }
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
