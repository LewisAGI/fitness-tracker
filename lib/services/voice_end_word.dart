/// "done" / "I'm done" at the end of a voice log.
class VoiceEndWord {
  static final _trailing = RegExp(
    r"""(?<!\bnot\s)(?<!\bwell\s)(?<!\bnever\s)(?<!\balmost\s)(?<!\ball\s)(?:\b(?:i'm|i am|im)\s+)?\bdone\b[\s.!?]*$""",
    caseSensitive: false,
  );

  static String _prepare(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll(RegExp(r'\s+'), ' ');

  static bool endsLog(String input) {
    final text = _prepare(input);
    if (text.isEmpty) {
      return false;
    }
    return _trailing.hasMatch(text);
  }

  static String strip(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final cleaned = _prepare(trimmed);
    return cleaned.replaceFirst(_trailing, '').trim();
  }
}
