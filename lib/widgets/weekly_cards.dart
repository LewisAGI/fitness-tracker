import 'package:flutter/material.dart';

import '../models/training.dart';
import '../theme/app_theme.dart';

class WeeklyCards extends StatelessWidget {
  const WeeklyCards({super.key, required this.suggestions});

  final List<StoredSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      key: const ValueKey('weekly-cards'),
      children: [
        for (final suggestion in suggestions)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Icon(
                  suggestion.suggestedWeightKg > suggestion.workingWeightKg
                      ? Icons.arrow_upward
                      : Icons.arrow_forward,
                  color: AppColors.accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
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
            ),
          ),
      ],
    );
  }
}
