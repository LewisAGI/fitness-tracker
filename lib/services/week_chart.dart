enum ChartPeriod { day, week, threeMonths, year }

class LoadSeries {
  const LoadSeries({
    required this.title,
    required this.points,
    required this.labels,
    required this.total,
    required this.target,
    required this.overreach,
    required this.percent,
  });

  final String title;
  final List<double> points;
  final List<String> labels;
  final double total;

  /// Mean of up to four earlier periods that had load. The current total when none did.
  final double target;

  /// 1.3 × [target]. The dotted overreach line.
  final double overreach;
  final int percent;
}

/// [priorTotals] is oldest to newest. Zeros are ignored. At most the latest four count.
LoadSeries seriesFrom({
  required String title,
  required List<double> points,
  required List<String> labels,
  required List<double> priorTotals,
}) {
  final total = points.fold<double>(0, (sum, value) => sum + value);
  final used = [for (final value in priorTotals) if (value > 0) value];
  final window = used.length <= 4 ? used : used.sublist(used.length - 4);
  final double target;
  if (window.isEmpty) {
    target = total > 0 ? total : 0;
  } else {
    target = window.reduce((a, b) => a + b) / window.length;
  }
  final percent = target <= 0 ? 0 : (100 * total / target).round();
  return LoadSeries(
    title: title,
    points: points,
    labels: labels,
    total: total,
    target: target,
    overreach: target * 1.3,
    percent: percent,
  );
}
