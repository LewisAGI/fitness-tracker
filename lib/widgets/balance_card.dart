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
    final bars = regionBars(report);
    var busiest = 0;
    for (final bar in bars) {
      if (bar.sets > busiest) {
        busiest = bar.sets;
      }
    }
    return Container(
      key: const ValueKey('balance'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: cardBox(),
      child: Column(
        children: [
          for (final bar in bars) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      bar.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(child: _bar(bar, busiest)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${bar.sets}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          for (final flag in report.flags)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  flag,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(RegionBar bar, int busiest) {
    final double shown;
    if (busiest <= 0) {
      shown = 0;
    } else if (bar.sets <= 0) {
      shown = bar.neglected ? 0.06 : 0;
    } else {
      final fraction = bar.sets / busiest;
      shown = fraction < 0.06 ? 0.06 : fraction;
    }
    final color = bar.neglected ? AppColors.accent : AppColors.ink;
    return SizedBox(
      height: 8,
      child: Align(
        alignment: Alignment.centerLeft,
        child: shown <= 0
            ? const SizedBox(height: 8)
            : FractionallySizedBox(
                widthFactor: shown,
                child: Container(
                  key: ValueKey('balance-bar-${bar.label}'),
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
      ),
    );
  }
}
