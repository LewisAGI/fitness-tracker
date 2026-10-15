/// End of a voice log: "done", "I'm done", "all done", "that's it", "finished".
class VoiceEndWord {
  /// Optional "all" / "I'm" / "I am" prefixes, repeated, so they are stripped
  /// with the cue and do not stay in the transcript.
  static const _prefix = r"(?:(?:\b(?:all|i'm|im|i\s+am)\b\s+)*)";

  static final _cue = RegExp(
    '(?:'
    "$_prefix(?:that's|thats)\\s+it|"
    '${_prefix}finished|'
    '${_prefix}done'
    r')[\s.!?]*$',
    caseSensitive: false,
  );

  static String _prepare(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll(RegExp(r'\s+'), ' ');

  static String _collapse(String input) => input
      .trim()
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool endsLog(String input) {
    final text = _prepare(input);
    if (text.isEmpty) {
      return false;
    }
    final match = _cue.firstMatch(text);
    if (match == null) {
      return false;
    }
    return !_blocked(text, match.start);
  }

  /// Drops a trailing end phrase and keeps the original case.
  static String strip(String input) {
    final collapsed = _collapse(input);
    if (collapsed.isEmpty) {
      return '';
    }
    final match = _cue.firstMatch(collapsed);
    if (match == null) {
      return collapsed;
    }
    final lower = collapsed.toLowerCase();
    if (_blocked(lower, match.start)) {
      return collapsed;
    }
    return collapsed.replaceRange(match.start, match.end, '').trim();
  }

  /// A negation blocks only when it sits directly on the cue, with at most
  /// one "quite" or "yet" between. A number or a unit stops the look.
  static bool _blocked(String text, int cueStart) {
    final prior = text.substring(0, cueStart).trim();
    if (prior.isEmpty) {
      return false;
    }
    final words = prior.split(RegExp(r'\s+'));
    final last = _token(words.last);
    if (_numberOrUnit(last)) {
      return false;
    }
    if (last == 'quite' || last == 'yet' || last == 'really' || last == 'fully') {
      if (words.length < 2) {
        return false;
      }
      final before = _token(words[words.length - 2]);
      if (_numberOrUnit(before)) {
        return false;
      }
      return _endNegation(before);
    }
    return _endNegation(last);
  }

  static String _token(String raw) => raw.replaceAll(RegExp(r"[^a-z0-9']"), '');

  static bool _numberOrUnit(String token) {
    if (RegExp(r'^\d').hasMatch(token)) {
      return true;
    }
    const units = {
      'kg',
      'k',
      'kilo',
      'kilos',
      'kilogram',
      'kilograms',
      'lb',
      'lbs',
      'pound',
      'pounds',
      'km',
      'kilometre',
      'kilometres',
      'kilometer',
      'kilometers',
      'rep',
      'reps',
      'set',
      'sets',
      'min',
      'mins',
      'minute',
      'minutes',
    };
    return units.contains(token);
  }

  static bool _endNegation(String word) {
    if (word.endsWith("n't")) {
      return true;
    }
    if (RegExp(
      r"^(?:was|were|is|are|did|does|do|had|has|have|would|could|should|must|need|ai|wo|ca)nt$",
    ).hasMatch(word)) {
      return true;
    }
    const words = {
      'not',
      'nowhere',
      'never',
      'no',
      'well',
      'almost',
      'nearly',
      'hardly',
      'barely',
    };
    return words.contains(word);
  }
}
