import 'package:flutter/material.dart';

import '../data/store.dart';
import '../services/dates.dart';
import '../services/share_export.dart';
import '../theme/app_theme.dart';
import '../widgets/balance_card.dart';
import '../widgets/confirm_action.dart';
import '../widgets/icon_tip.dart';
import '../widgets/weekly_cards.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.store});

  final Store store;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  WeekBundle? _week;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.store.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final week = await widget.store.loadWeek(widget.store.now());
    if (mounted) {
      setState(() => _week = week);
    }
  }

  @override
  Widget build(BuildContext context) {
    final week = _week;
    return Scaffold(
      appBar: AppBar(
        title: Text(week == null ? 'Plan' : fmtRange(week.start, week.start.add(const Duration(days: 6)))),
        actions: [
          IconTip(
            icon: Icons.ios_share,
            message: 'Export week',
            onPressed: () {
              final current = _week;
              if (current != null) {
                _export(current);
              }
            },
          ),
        ],
      ),
      body: week == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                BalanceCard(report: week.balance),
                WeeklyCards(
                  suggestions: week.suggestions,
                  goalLines: week.goalLines,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 280,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final day in week.days)
                        Expanded(child: _dayColumn(day)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _export(WeekBundle week) async {
    final files = await widget.store.exportRange(
      start: week.start,
      end: week.start.add(const Duration(days: 6)),
      kind: 'week',
    );
    if (!mounted) {
      return;
    }
    await offerExport(context, files);
  }

  Widget _dayColumn(DayBundle day) {
    final warning = day.warnings.isEmpty ? null : day.warnings.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Text(
            weekdayLabels[day.date.weekday - 1],
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          Text(
            '${day.date.day}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: InkWell(
              key: ValueKey('day-${isoDate(day.date)}'),
              onTap: () => _openDay(day),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.hairline),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    for (final plan in day.plans)
                      Icon(
                        _icon(plan.type),
                        color: AppColors.accent,
                        size: 18,
                      ),
                    if (warning != null)
                      IconButton(
                        key: ValueKey('warning-${isoDate(day.date)}'),
                        tooltip: 'Warning',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: () => _openWarning(day),
                        icon: Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: warning.level == 'muted'
                              ? AppColors.muted
                              : AppColors.accent,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWarning(DayBundle day) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final warning in day.warnings) ...[
                Text(warning.evidence),
                const SizedBox(height: 8),
                for (final date in warning.evidenceDates)
                  IconTip(
                    icon: Icons.event,
                    message: fmtDay(parseIsoDate(date)),
                    onPressed: () {
                      Navigator.pop(context);
                      _openHistoryDate(date);
                    },
                  ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: IconTip(
                  icon: Icons.close,
                  message: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openHistoryDate(String iso) {
    widget.store.pendingSlot.value = 'history:$iso';
  }

  Future<void> _openDay(DayBundle day) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  fmtWeekdayDate(day.date),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final plan in day.plans)
                ListTile(
                  title: Text(planLine(plan)),
                  subtitle: plan.suggestion == null
                      ? null
                      : Text(plan.suggestion!),
                  trailing: IconTip(
                    icon: Icons.delete_outline,
                    message: 'Remove',
                    onPressed: () async {
                      final ok = await confirmChoice(context);
                      if (!ok || !context.mounted) {
                        return;
                      }
                      await widget.store.deletePlan(plan.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconTip(
                    icon: Icons.add,
                    message: 'Add',
                    onPressed: () async {
                      Navigator.pop(context);
                      await _add(day.date);
                    },
                  ),
                  IconTip(
                    icon: Icons.close,
                    message: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _add(DateTime date) async {
    final type = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const [
              ('gym', 'Gym', Icons.fitness_center),
              ('muay_thai', 'Muay Thai', Icons.sports_martial_arts),
              ('run', 'Run', Icons.directions_run),
              ('hike', 'Hike', Icons.hiking),
              ('yoga', 'Yoga', Icons.self_improvement),
            ])
              ListTile(
                leading: Icon(entry.$3, color: AppColors.accent),
                title: Text(entry.$2),
                onTap: () => Navigator.pop(context, entry.$1),
              ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) {
      return;
    }
    List<String> muscles = const [];
    if (type == 'gym') {
      final muscle = await showDialog<String>(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final name in const [
                'legs',
                'chest',
                'back',
                'shoulders',
                'arms',
                'core',
              ])
                ListTile(
                  title: Text(name),
                  onTap: () => Navigator.pop(context, name),
                ),
            ],
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      if (muscle != null) {
        muscles = [muscle];
      }
    }
    final intensity = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final name in const ['easy', 'moderate', 'hard'])
              ListTile(
                title: Text(name),
                onTap: () => Navigator.pop(context, name),
              ),
          ],
        ),
      ),
    );
    if (intensity == null) {
      return;
    }
    await widget.store.addPlan(
      date: date,
      type: type,
      muscleGroups: muscles,
      intensity: intensity,
    );
  }
}

IconData _icon(String type) => switch (type) {
  'muay_thai' => Icons.sports_martial_arts,
  'run' => Icons.directions_run,
  'hike' => Icons.hiking,
  'yoga' => Icons.self_improvement,
  _ => Icons.fitness_center,
};
