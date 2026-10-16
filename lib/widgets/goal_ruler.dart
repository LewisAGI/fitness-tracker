import 'package:flutter/material.dart';

import '../models/training.dart';
import '../services/normalise.dart';
import '../theme/app_theme.dart';

class GoalBoard extends StatelessWidget {
  const GoalBoard({
    super.key,
    required this.lines,
    required this.goals,
    required this.onTarget,
  });

  final List<String> lines;
  final List<Goal> goals;
  final void Function(int id, double kg) onTarget;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        for (final line in lines)
          _GoalCard(
            line: line,
            lift: _liftFor(line, goals),
            onTarget: onTarget,
          ),
      ],
    );
  }
}

Goal? _liftFor(String line, List<Goal> goals) {
  for (final goal in goals) {
    final name = goal.exerciseName;
    if (goal.kind == GoalKind.lift &&
        name != null &&
        name.isNotEmpty &&
        line.startsWith(name)) {
      return goal;
    }
  }
  return null;
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.line,
    required this.lift,
    required this.onTarget,
  });

  final String line;
  final Goal? lift;
  final void Function(int id, double kg) onTarget;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('goal-progress'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (lift != null) ...[
            const SizedBox(height: 12),
            GoalRuler(
              value: lift!.targetKg ?? 60,
              onChanged: (kg) => onTarget(lift!.id, kg),
            ),
          ],
        ],
      ),
    );
  }
}

class GoalRuler extends StatefulWidget {
  const GoalRuler({super.key, required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<GoalRuler> createState() => _GoalRulerState();
}

class _GoalRulerState extends State<GoalRuler> {
  static const _min = 20.0;
  static const _max = 200.0;
  double? _drag;

  double get _value => _drag ?? widget.value;

  double _snap(double kg) {
    final clamped = kg.clamp(_min, _max).toDouble();
    return (clamped * 2).roundToDouble() / 2;
  }

  void _fromDx(double dx, double width, {required bool commit}) {
    if (width <= 0) {
      return;
    }
    final t = (dx / width).clamp(0.0, 1.0);
    final kg = _snap(_min + t * (_max - _min));
    setState(() => _drag = kg);
    if (commit) {
      widget.onChanged(kg);
      setState(() => _drag = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _value.clamp(_min, _max);
    final t = (shown - _min) / (_max - _min);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.lerp(Alignment.centerLeft, Alignment.centerRight, t)!,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${fmtKg(shown.toDouble())} kg',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              key: const ValueKey('goal-ruler'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) => _fromDx(
                details.localPosition.dx,
                constraints.maxWidth,
                commit: false,
              ),
              onHorizontalDragEnd: (_) {
                final kg = _drag;
                if (kg != null) {
                  widget.onChanged(kg);
                  setState(() => _drag = null);
                }
              },
              onTapDown: (details) => _fromDx(
                details.localPosition.dx,
                constraints.maxWidth,
                commit: true,
              ),
              child: CustomPaint(
                size: Size(constraints.maxWidth, 36),
                painter: _RulerPainter(value: shown.toDouble()),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const min = 20.0;
    const max = 200.0;
    final baseline = size.height - 8;
    final track = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, baseline), Offset(size.width, baseline), track);
    for (var kg = min; kg <= max; kg += 5) {
      final x = (kg - min) / (max - min) * size.width;
      final major = kg % 20 == 0;
      canvas.drawLine(
        Offset(x, baseline),
        Offset(x, baseline - (major ? 14 : 8)),
        Paint()
          ..color = major ? AppColors.muted : AppColors.hairline
          ..strokeWidth = major ? 1.4 : 1,
      );
    }
    final thumbX = (value.clamp(min, max) - min) / (max - min) * size.width;
    canvas.drawCircle(
      Offset(thumbX, baseline),
      7,
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) => oldDelegate.value != value;
}
