import 'package:flutter/material.dart';

import '../models/training.dart';
import '../theme/app_theme.dart';

class WeeklyCards extends StatelessWidget {
  const WeeklyCards({
    super.key,
    required this.suggestions,
    this.goalLines = const [],
  });

  final List<StoredSuggestion> suggestions;
  final List<String> goalLines;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty && goalLines.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      key: const ValueKey('weekly-cards'),
      children: [
        for (final line in goalLines)
          Container(
            key: const ValueKey('goal-progress'),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              line,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        for (final suggestion in suggestions)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              suggestion.card,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
