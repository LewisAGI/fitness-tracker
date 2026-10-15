/// Light transcript tidy: drop spoken fillers and squeeze leftover space.
///
/// Same filler list as Shelf. The parser keeps the result lowercase.
class FillerCleanup {
  static const defaultFillers = <String>[
    'um',
    'uh',
    'uhm',
    'erm',
    'er',
    'ah',
    'like',
  ];

  static String clean(String input, {Iterable<String>? fillers}) {
    if (input.trim().isEmpty) {
      return '';
    }

    final tokens = (fillers ?? defaultFillers)
        .map((word) => RegExp.escape(word.trim()))
        .where((word) => word.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return _tidyPunctuation(input.trim());
    }

    final pattern = RegExp(
      '\\b(?:${tokens.join('|')})\\b',
      caseSensitive: false,
    );

    var text = input.replaceAll(pattern, ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _tidyPunctuation(text);
  }

  static String _tidyPunctuation(String text) {
    var result = text.replaceAllMapped(
      RegExp(r'\s+([,.;:!?])'),
      (match) => match.group(1)!,
    );
    result = result.replaceAllMapped(
      RegExp(r'([,.;:!?])\1+'),
      (match) => match.group(1)!,
    );
    return result;
  }
}
