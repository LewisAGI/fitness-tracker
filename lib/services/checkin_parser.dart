import 'normalise.dart';

class ParsedCheckIn {
  const ParsedCheckIn({
    required this.normalised,
    this.soreness,
    this.energy,
    this.sleepQuality,
    this.sleepHours,
    this.mood,
    this.stress,
    this.sessionFeel,
    this.ateWell,
  });

  final String normalised;
  final int? soreness;
  final int? energy;
  final int? sleepQuality;
  final double? sleepHours;
  final int? mood;
  final int? stress;
  final int? sessionFeel;
  final int? ateWell;
}

ParsedCheckIn parseCheckIn(String input) {
  var text = normaliseTranscript(input);
  double? sleepHours;
  final hourPatterns = [
    RegExp(r'\bslept\s+(\d+(?:\.\d+)?)\s+hours?\b'),
    RegExp(r'\b(\d+(?:\.\d+)?)\s+hours?\s+(?:of\s+)?sleep\b'),
    RegExp(r'\bsleep hours\s+(\d+(?:\.\d+)?)\b'),
  ];
  for (final pattern in hourPatterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      sleepHours = double.parse(match.group(1)!);
      text = text.replaceRange(match.start, match.end, ' ');
      break;
    }
  }
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  int? score(List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return int.parse(match.group(1)!).clamp(1, 10);
      }
    }
    return null;
  }

  return ParsedCheckIn(
    normalised: normaliseTranscript(input),
    soreness: score([RegExp(r'\b(?:sore|soreness)\s+(\d+)\b')]),
    energy: score([RegExp(r'\benergy\s+(\d+)\b')]),
    sleepQuality: score([
      RegExp(r'\b(?:sleep quality|quality of sleep)\s+(\d+)\b'),
    ]),
    sleepHours: sleepHours,
    mood: score([RegExp(r'\bmood\s+(\d+)\b')]),
    stress: score([RegExp(r'\bstress\s+(\d+)\b')]),
    sessionFeel: score([
      RegExp(r'\b(?:session feel|session|feel)\s+(\d+)\b'),
    ]),
    ateWell: score([RegExp(r'\b(?:ate well|ate|food)\s+(\d+)\b')]),
  );
}
