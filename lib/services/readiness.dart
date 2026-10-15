class ReadinessScore {
  const ReadinessScore({required this.readiness, required this.fatigue});

  final double readiness;
  final double fatigue;
}

ReadinessScore? scoreCheckIns({
  int? soreness,
  int? energy,
  int? sleepQuality,
  int? mood,
  int? stress,
  int? eveningEnergy,
  int? ateWell,
  int? sessionFeel,
  int? eveningStress,
}) {
  final parts = <double>[];
  void add(num? value) {
    if (value != null) {
      parts.add(value.toDouble());
    }
  }

  add(energy);
  add(sleepQuality);
  add(mood);
  if (soreness != null) {
    add(11 - soreness);
  }
  if (stress != null) {
    add(11 - stress);
  }
  add(eveningEnergy);
  add(ateWell);
  add(sessionFeel);
  if (eveningStress != null) {
    add(11 - eveningStress);
  }
  if (parts.isEmpty) {
    return null;
  }
  final mean = parts.reduce((a, b) => a + b) / parts.length;
  final readiness = ((mean - 1) / 9) * 100;
  final fatigueParts = <double>[];
  if (soreness != null) {
    fatigueParts.add(soreness.toDouble());
  }
  if (energy != null) {
    fatigueParts.add((11 - energy).toDouble());
  }
  if (eveningEnergy != null) {
    fatigueParts.add((11 - eveningEnergy).toDouble());
  }
  final fatigue = fatigueParts.isEmpty
      ? (11 - mean).clamp(1, 10).toDouble()
      : fatigueParts.reduce((a, b) => a + b) / fatigueParts.length;
  return ReadinessScore(readiness: readiness, fatigue: fatigue);
}

double? meanReadiness(Iterable<double?> daily) {
  final values = daily.whereType<double>().toList();
  if (values.isEmpty) {
    return null;
  }
  return values.reduce((a, b) => a + b) / values.length;
}
