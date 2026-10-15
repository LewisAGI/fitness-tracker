import 'dates.dart';
import 'load_model.dart';

class PatternSample {
  const PatternSample({
    required this.key,
    required this.outcomeDate,
    required this.readiness,
    required this.fatigue,
  });

  final String key;
  final DateTime outcomeDate;
  final double readiness;
  final double fatigue;
}

class PatternStats {
  const PatternStats({
    required this.key,
    required this.n,
    required this.meanReadiness,
    required this.meanFatigue,
    required this.window,
  });

  final String key;
  final int n;
  final double meanReadiness;
  final double meanFatigue;
  final List<PatternSample> window;

  static const empty = PatternStats(
    key: '',
    n: 0,
    meanReadiness: 0,
    meanFatigue: 0,
    window: [],
  );
}

enum PatternEffect { none, upgrade, downgrade }

class DaySignatureInput {
  const DaySignatureInput({
    required this.type,
    this.rpe,
    this.intensity,
    this.muscleGroups = const [],
    this.subtypes = const [],
    this.load = 0,
  });

  final String type;
  final int? rpe;
  final String? intensity;
  final List<String> muscleGroups;
  final List<String> subtypes;
  final double load;
}

class PatternBook {
  final List<PatternSample> samples = [];

  void upsert(PatternSample sample) {
    samples.removeWhere(
      (existing) =>
          existing.key == sample.key &&
          sameDay(existing.outcomeDate, sample.outcomeDate),
    );
    samples.add(sample);
  }

  void learn({
    required DateTime outcomeDay,
    required List<DaySignatureInput> dayMinus1,
    required List<DaySignatureInput> dayMinus2,
    required double readiness,
    required double fatigue,
  }) {
    for (final key in patternKeys(dayMinus1: dayMinus1, dayMinus2: dayMinus2)) {
      upsert(
        PatternSample(
          key: key,
          outcomeDate: dateOnly(outcomeDay),
          readiness: readiness,
          fatigue: fatigue,
        ),
      );
    }
  }

  PatternStats stats(String key) {
    final mine =
        samples.where((sample) => sample.key == key).toList()..sort(
          (a, b) => a.outcomeDate.compareTo(b.outcomeDate),
        );
    if (mine.isEmpty) {
      return PatternStats(
        key: key,
        n: 0,
        meanReadiness: 0,
        meanFatigue: 0,
        window: const [],
      );
    }
    final window = mine.length <= 8 ? mine : mine.sublist(mine.length - 8);
    final readiness =
        window.fold<double>(0, (sum, sample) => sum + sample.readiness) /
        window.length;
    final fatigue =
        window.fold<double>(0, (sum, sample) => sum + sample.fatigue) /
        window.length;
    return PatternStats(
      key: key,
      n: window.length,
      meanReadiness: readiness,
      meanFatigue: fatigue,
      window: window,
    );
  }
}

List<String> patternKeys({
  required List<DaySignatureInput> dayMinus1,
  required List<DaySignatureInput> dayMinus2,
}) {
  final previous = daySignature(dayMinus1);
  if (previous == 'rest') {
    return const [];
  }
  final keys = <String>[previous];
  final earlier = daySignature(dayMinus2);
  if (earlier != 'rest') {
    keys.add('$earlier>$previous');
  }
  return keys;
}

String daySignature(List<DaySignatureInput> sessions) {
  if (sessions.isEmpty) {
    return 'rest';
  }
  final ordered = [...sessions]..sort((a, b) => b.load.compareTo(a.load));
  final session = ordered.first;
  return sessionSignature(
    type: session.type,
    rpe: session.rpe,
    intensity: session.intensity,
    muscleGroups: session.muscleGroups,
    subtypes: session.subtypes,
  );
}

PatternEffect patternEffect(PatternStats stats) {
  if (stats.n < 3) {
    return PatternEffect.none;
  }
  if (stats.meanFatigue >= 7 || stats.meanReadiness < 45) {
    return PatternEffect.upgrade;
  }
  if (stats.meanFatigue <= 4 && stats.meanReadiness >= 65) {
    return PatternEffect.downgrade;
  }
  return PatternEffect.none;
}

String prettySignature(String signature) {
  if (signature == 'muay_thai:hard') {
    return 'Thai hard';
  }
  if (signature == 'gym:legs_heavy') {
    return 'legs heavy';
  }
  if (signature.startsWith('muay_thai:')) {
    final rest = signature.substring('muay_thai:'.length).replaceAll('_', ' ');
    return 'Thai $rest';
  }
  if (signature.startsWith('gym:')) {
    return signature.substring(4).replaceAll('_', ' ');
  }
  return signature.replaceAll('_', ' ').replaceAll(':', ' ');
}

String prettyPatternKey(String key) {
  if (key.contains('>')) {
    final bits = key.split('>');
    return '${prettySignature(bits[0])} → ${prettySignature(bits[1])}';
  }
  return prettySignature(key);
}

String patternEvidence(PatternStats stats) {
  final last = stats.window.length <= 3
      ? stats.window
      : stats.window.sublist(stats.window.length - 3);
  final fatigues = last.map((sample) => _fmt(sample.fatigue)).join(', ');
  final label = last.length == 1 ? '1 time' : '${last.length} times';
  return 'Last $label: ${prettyPatternKey(stats.key)}. Next-day fatigue $fatigues.';
}

String _fmt(double value) {
  if ((value - value.round()).abs() < 0.05) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
