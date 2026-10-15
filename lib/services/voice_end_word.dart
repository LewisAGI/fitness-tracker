/// End of a voice log: "done", "I'm done", "all done", "that's it", "finished".
class VoiceEndWord {
  static final _cue = RegExp(
    r"""(?:\b(?:that's|thats)\s+it\b|\bfinished\b|(?:\b(?:i'm|i am|im)\s+)?\bdone\b)[\s.!?]*$""",
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

  static bool _blocked(String text, int cueStart) {
    final prior = text.substring(0, cueStart).trim();
    if (prior.isEmpty) {
      return false;
    }
    final words = prior.split(RegExp(r'\s+'));
    final start = words.length > 3 ? words.length - 3 : 0;
    for (var i = start; i < words.length; i++) {
      final word = words[i].replaceAll(RegExp(r"[^a-z']"), '');
      if (word == "i'm" || word == 'im' || word == 'i' || word == 'am' || word == 'all') {
        continue;
      }
      if (_endNegation(word)) {
        return true;
      }
    }
    return false;
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
