import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/training.dart';
import '../services/goals.dart';
import '../services/normalise.dart';
import '../theme/app_theme.dart';
import 'icon_tip.dart';

Future<void> showGoalsEditor(BuildContext context, Store store) {
  return showDialog<void>(
    context: context,
    builder: (context) => _GoalsDialog(store: store),
  );
}

class _GoalsDialog extends StatefulWidget {
  const _GoalsDialog({required this.store});

  final Store store;

  @override
  State<_GoalsDialog> createState() => _GoalsDialogState();
}

class _GoalsDialogState extends State<_GoalsDialog> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = widget.store.goals;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final goal in goals)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _goalLabel(goal),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconTip(
                    icon: Icons.delete_outline,
                    message: 'Delete',
                    onPressed: () => widget.store.deleteGoal(goal.id),
                  ),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconTip(
                  icon: Icons.add,
                  message: 'Add',
                  onPressed: () => _add(context),
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
    );
  }

  Future<void> _add(BuildContext context) async {
    final kind = await showDialog<GoalKind>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTip(
                icon: Icons.speed,
                message: 'Pace',
                onPressed: () => Navigator.pop(context, GoalKind.pace),
              ),
              IconTip(
                icon: Icons.fitness_center,
                message: 'Lift',
                onPressed: () => Navigator.pop(context, GoalKind.lift),
              ),
              IconTip(
                icon: Icons.track_changes,
                message: 'General',
                onPressed: () => Navigator.pop(context, GoalKind.general),
              ),
            ],
          ),
        ),
      ),
    );
    if (kind == null || !context.mounted) {
      return;
    }
    switch (kind) {
      case GoalKind.pace:
        await _addPace(context);
      case GoalKind.lift:
        await _addLift(context);
      case GoalKind.general:
        await _addGeneral(context);
    }
  }

  Future<void> _addPace(BuildContext context) async {
    final distance = TextEditingController();
    final pace = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: distance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixIcon: Tooltip(
                    message: 'Distance',
                    child: Icon(Icons.straighten, color: AppColors.accent),
                  ),
                ),
              ),
              TextField(
                controller: pace,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  prefixIcon: Tooltip(
                    message: 'Pace',
                    child: Icon(Icons.timer_outlined, color: AppColors.accent),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconTip(
                  icon: Icons.check,
                  message: 'Save',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final kilometres = double.tryParse(distance.text.trim());
    final seconds = parsePaceMinPerKm(pace.text);
    distance.dispose();
    pace.dispose();
    if (saved != true || kilometres == null || kilometres <= 0 || seconds == null) {
      return;
    }
    await widget.store.addGoal(
      kind: GoalKind.pace,
      distanceKm: roundKm(kilometres),
      targetPaceS: seconds,
    );
  }

  Future<void> _addLift(BuildContext context) async {
    final exercise = await _pickExercise(context);
    if (exercise == null || !context.mounted) {
      return;
    }
    final kilograms = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              TextField(
                controller: kilograms,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixIcon: Tooltip(
                    message: 'kg',
                    child: Icon(Icons.fitness_center, color: AppColors.accent),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconTip(
                  icon: Icons.check,
                  message: 'Save',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final weight = double.tryParse(kilograms.text.trim());
    kilograms.dispose();
    if (saved != true || weight == null || weight <= 0) {
      return;
    }
    await widget.store.addGoal(
      kind: GoalKind.lift,
      exerciseId: exercise.id,
      targetKg: weight,
    );
  }

  Future<void> _addGeneral(BuildContext context) async {
    final general = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTip(
                icon: Icons.fitness_center,
                message: 'Strength',
                onPressed: () => Navigator.pop(context, 'strength'),
              ),
              IconTip(
                icon: Icons.directions_run,
                message: 'Fitness',
                onPressed: () => Navigator.pop(context, 'fitness'),
              ),
              IconTip(
                icon: Icons.expand,
                message: 'Hypertrophy',
                onPressed: () => Navigator.pop(context, 'hypertrophy'),
              ),
            ],
          ),
        ),
      ),
    );
    if (general == null) {
      return;
    }
    await widget.store.addGoal(kind: GoalKind.general, general: general);
  }

  Future<Exercise?> _pickExercise(BuildContext context) {
    final exercises = widget.store.exercises
        .where((exercise) => exercise.category == 'strength')
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return showDialog<Exercise>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 320,
          height: 420,
          child: ListView(
            children: [
              for (final exercise in exercises)
                ListTile(
                  title: Text(exercise.name),
                  onTap: () => Navigator.pop(context, exercise),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _goalLabel(Goal goal) {
  return switch (goal.kind) {
    GoalKind.general => switch (goal.general) {
      'strength' => 'Strength',
      'fitness' => 'Fitness',
      'hypertrophy' => 'Hypertrophy',
      _ => 'Goal',
    },
    GoalKind.lift =>
      '${goal.exerciseName ?? 'Lift'} · ${goal.targetKg == null ? '-' : fmtKg(goal.targetKg!)} kg',
    GoalKind.pace =>
      '${goal.distanceKm == null ? '-' : fmtKm(goal.distanceKm!)} km · ${goal.targetPaceS == null ? '-' : '${fmtClock(goal.targetPaceS!)}/km'}',
  };
}
