import 'package:flutter/material.dart';

import '../models/training.dart';
import '../services/goals.dart';
import '../theme/app_theme.dart';

class PaceFlagIcon extends StatelessWidget {
  const PaceFlagIcon({super.key, required this.session, required this.goals});

  final Session session;
  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    final lines = paceFlagLines(session, goals);
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: lines.join('\n'),
      child: const Icon(Icons.speed, color: AppColors.accent, size: 22),
    );
  }
}
