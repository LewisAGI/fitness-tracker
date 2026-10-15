class BlockLoad {
  const BlockLoad({required this.durationMin, required this.rpe});

  final int durationMin;
  final int rpe;
}

class MuscleSet {
  const MuscleSet({
    required this.at,
    required this.muscles,
    required this.sets,
  });

  final DateTime at;
  final List<String> muscles;
  final int sets;
}

const legGroups = {'legs', 'quads', 'hamstrings', 'glutes', 'calves'};

bool isLowerBody(Iterable<String> muscles) {
  for (final muscle in muscles) {
    if (legGroups.contains(muscle.toLowerCase())) {
      return true;
    }
  }
  return false;
}

String focusMuscle(List<String> muscles) {
  for (final muscle in muscles) {
    if (legGroups.contains(muscle.toLowerCase())) {
      return 'legs';
    }
  }
  if (muscles.isEmpty) {
    return 'full';
  }
  return muscles.first.toLowerCase();
}

int resolvedRpe({
  required String type,
  int? rpe,
  String? intensity,
  int rpeSampleCount = 0,
  double? meanRpe,
}) {
  if (rpe != null) {
    return rpe;
  }
  if (rpeSampleCount >= 5 && meanRpe != null) {
    return meanRpe.round();
  }
  if (type == 'gym') {
    if (intensity == 'easy') {
      return 3;
    }
    if (intensity == 'moderate') {
      return 5;
    }
    return 7;
  }
  return switch (type) {
    'muay_thai' => 7,
    'run' => 6,
    'hike' => 4,
    'yoga' => 2,
    _ => 5,
  };
}

double sessionLoad({
  required String type,
  int? durationMin,
  int? rpe,
  int setCount = 0,
  String? intensity,
  List<BlockLoad> blocks = const [],
  int rpeSampleCount = 0,
  double? meanRpe,
}) {
  if (blocks.isNotEmpty) {
    return blocks.fold<double>(
      0,
      (sum, block) => sum + block.durationMin * block.rpe,
    );
  }
  final used = resolvedRpe(
    type: type,
    rpe: rpe,
    intensity: intensity,
    rpeSampleCount: rpeSampleCount,
    meanRpe: meanRpe,
  );
  var minutes = durationMin ?? 0;
  if (minutes == 0 && type == 'gym') {
    minutes = setCount * 3;
  }
  return (minutes * used).toDouble();
}

double percentile75(List<double> values) {
  if (values.isEmpty) {
    return double.infinity;
  }
  final sorted = [...values]..sort();
  final rank = 0.75 * (sorted.length - 1);
  final lower = rank.floor();
  final upper = rank.ceil();
  if (lower == upper) {
    return sorted[lower];
  }
  return sorted[lower] + (sorted[upper] - sorted[lower]) * (rank - lower);
}

int muscleGroupSets({
  required List<MuscleSet> entries,
  required String muscle,
  required DateTime at,
}) {
  final from = at.subtract(const Duration(hours: 72));
  final target = muscle.toLowerCase();
  var total = 0;
  for (final entry in entries) {
    if (entry.at.isBefore(from) || entry.at.isAfter(at)) {
      continue;
    }
    if (entry.muscles.any((item) => item.toLowerCase() == target)) {
      total += entry.sets;
    }
  }
  return total;
}

double weeklyLoad(Iterable<double> sessionLoads) =>
    sessionLoads.fold<double>(0, (sum, load) => sum + load);

double? acuteChronicRatio({
  required double thisWeek,
  required List<double> previousWeeks,
}) {
  if (previousWeeks.length < 3) {
    return null;
  }
  final window = previousWeeks.length <= 4
      ? previousWeeks
      : previousWeeks.sublist(previousWeeks.length - 4);
  final average = window.reduce((a, b) => a + b) / window.length;
  if (average == 0) {
    return null;
  }
  return thisWeek / average;
}

String sessionSignature({
  required String type,
  int? rpe,
  String? intensity,
  List<String> muscleGroups = const [],
  List<String> subtypes = const [],
}) {
  final hard = (rpe != null && rpe >= 7) || intensity == 'hard';
  switch (type) {
    case 'muay_thai':
      if (subtypes.length == 1) {
        return 'muay_thai:${subtypes.first}';
      }
      return hard ? 'muay_thai:hard' : 'muay_thai';
    case 'gym':
      final focus = focusMuscle(muscleGroups);
      return hard ? 'gym:${focus}_heavy' : 'gym:$focus';
    case 'run':
      return hard ? 'run:hard' : 'run';
    default:
      return hard ? '$type:hard' : type;
  }
}
