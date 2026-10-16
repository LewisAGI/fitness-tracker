import 'package:flutter/material.dart';

import '../services/week_chart.dart';
import '../theme/app_theme.dart';
import 'icon_tip.dart';

class LoadHero extends StatelessWidget {
  const LoadHero({
    super.key,
    required this.series,
    required this.period,
    required this.onPeriod,
  });

  final LoadSeries series;
  final ChartPeriod period;
  final ValueChanged<ChartPeriod> onPeriod;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('load-hero'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 14),
      decoration: cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  series.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconTip(
                key: const ValueKey('period'),
                icon: Icons.calendar_today_outlined,
                message: 'Period',
                onPressed: () => _pick(context),
              ),
            ],
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${series.percent}%',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.2,
                    color: AppColors.ink,
                  ),
                ),
                const TextSpan(
                  text: '  of target',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_num(series.total)} / ${_num(series.target)}',
            key: const ValueKey('load-percent'),
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(painter: _LoadPainter(series)),
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              _Legend(color: AppColors.muted, label: 'Target'),
              SizedBox(width: 16),
              _Legend(color: AppColors.accent, label: 'Overreach'),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final next = await showDialog<ChartPeriod>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          key: const ValueKey('period-menu'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const [
              (ChartPeriod.day, 'Day'),
              (ChartPeriod.week, 'Week'),
              (ChartPeriod.threeMonths, '3 months'),
              (ChartPeriod.year, 'Year'),
            ])
              ListTile(
                title: Text(entry.$2),
                trailing: entry.$1 == period
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.pop(context, entry.$1),
              ),
          ],
        ),
      ),
    );
    if (next != null) {
      onPeriod(next);
    }
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(22, 8),
          painter: _DashSample(color),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }
}

String _num(double value) {
  if (value >= 100 || (value - value.round()).abs() < 0.05) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

class _LoadPainter extends CustomPainter {
  _LoadPainter(this.series);

  final LoadSeries series;

  @override
  void paint(Canvas canvas, Size size) {
    const axisWidth = 36.0;
    final chart = Rect.fromLTWH(0, 8, size.width - axisWidth, size.height - 26);
    var maxY = series.overreach;
    if (series.target > maxY) {
      maxY = series.target;
    }
    for (final point in series.points) {
      if (point > maxY) {
        maxY = point;
      }
    }
    if (maxY <= 0) {
      maxY = 1;
    }
    double yOf(double value) => chart.bottom - (value / maxY) * chart.height;

    final targetPaint = Paint()
      ..color = AppColors.muted
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final overPaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    if (series.target > 0) {
      final y = yOf(series.target);
      _dash(canvas, Offset(chart.left, y), Offset(chart.right, y), targetPaint);
    }
    if (series.overreach > 0) {
      final y = yOf(series.overreach);
      _dash(canvas, Offset(chart.left, y), Offset(chart.right, y), overPaint);
    }

    final n = series.points.length;
    final spots = <Offset>[];
    for (var i = 0; i < n; i++) {
      final x = n == 1 ? chart.center.dx : chart.left + chart.width * i / (n - 1);
      spots.add(Offset(x, yOf(series.points[i])));
    }
    if (spots.length >= 2) {
      final path = Path()..moveTo(spots.first.dx, spots.first.dy);
      for (final spot in spots.skip(1)) {
        path.lineTo(spot.dx, spot.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.ink
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final dot = Paint()..color = AppColors.accent;
    for (final spot in spots) {
      canvas.drawCircle(spot, 3.5, dot);
    }

    const style = TextStyle(
      color: AppColors.muted,
      fontSize: 11,
      fontFamily: 'Roboto',
    );
    for (var i = 0; i < n; i++) {
      if (n > 8 && i != 0 && i != n - 1 && i != n ~/ 2) {
        continue;
      }
      final label = i < series.labels.length ? series.labels[i] : '';
      if (label.isEmpty) {
        continue;
      }
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(spots[i].dx - painter.width / 2, chart.bottom + 4),
      );
      painter.dispose();
    }
    for (final value in [0.0, maxY / 2, maxY]) {
      final painter = TextPainter(
        text: TextSpan(text: value.round().toString(), style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(chart.right + 4, yOf(value) - painter.height / 2),
      );
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(_LoadPainter oldDelegate) => true;
}

class _DashSample extends CustomPainter {
  _DashSample(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    _dash(
      canvas,
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()
        ..color = color
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_DashSample oldDelegate) => oldDelegate.color != color;
}

void _dash(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dash = 4.0;
  const gap = 4.0;
  final delta = end - start;
  final length = delta.distance;
  if (length == 0) {
    return;
  }
  final step = delta / length;
  var drawn = 0.0;
  while (drawn < length) {
    final from = start + step * drawn;
    final to = start + step * (drawn + dash).clamp(0, length);
    canvas.drawLine(from, to, paint);
    drawn += dash + gap;
  }
}
