import 'package:flutter/material.dart';

import '../services/balance.dart';
import '../theme/app_theme.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.report});

  final BalanceReport report;

  @override
  Widget build(BuildContext context) {
    if (report.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const ValueKey('balance'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final muscle in report.muscles)
            Text(
              muscleLine(muscle),
              style: const TextStyle(color: AppColors.ink, fontSize: 15),
            ),
          for (final flag in report.flags)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                flag,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
