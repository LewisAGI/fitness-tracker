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
    if (RegExp(r'^[a-z]').hasMatch(token)) {
      final tail = scheme.firstMatch(before);
      final head = tail == null ? before : before.substring(0, tail.start);
      final kept = tail == null ? '' : before.substring(tail.start);
      before = '${head.replaceFirst(name, '').trim()} ${kept.trim()}'.trim();
    } else {
      before = before.replaceFirst(RegExp(r'\S+\s*$'), '');
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

String _numberWords(String input) {
  final tokens = input.split(RegExp(r'\s+'));
  final out = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final raw = tokens[i];
    if (raw.isEmpty) {
      continue;
    }
    final match = RegExp(r"^([a-z-]+)([^a-z-]*)$").firstMatch(raw);
    if (match == null) {
      out.add(raw);
      continue;
    }
    final word = match.group(1)!;
    final suffix = match.group(2)!;
    if (_tens.containsKey(word) && i + 1 < tokens.length) {
      final nextMatch = RegExp(
        r'^([a-z-]+)([^a-z-]*)$',
      ).firstMatch(tokens[i + 1]);
      final next = nextMatch?.group(1);
      if (next != null && _ones.containsKey(next) && _ones[next]! < 10) {
        out.add('${_tens[word]! + _ones[next]!}${nextMatch!.group(2)!}');
        i++;
        continue;
      }
    }
    if (_ones.containsKey(word)) {
      out.add('${_ones[word]}$suffix');
      continue;
    }
    if (_tens.containsKey(word)) {
      out.add('${_tens[word]}$suffix');
      continue;
    }
    out.add(raw);
  }
  return out.join(' ');
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
