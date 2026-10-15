import 'dart:async';

import 'package:flutter/material.dart';

import '../models/training.dart';
import '../services/normalise.dart';
import '../services/voice_parser.dart';
import '../theme/app_theme.dart';
import 'icon_tip.dart';

class ConfirmCard extends StatefulWidget {
  const ConfirmCard({
    super.key,
    required this.result,
    required this.exercises,
    required this.onSave,
    required this.onAlias,
    this.autoSaveAfter = const Duration(seconds: 3),
  });

  final ParseResult result;
  final List<Exercise> exercises;
  final Future<void> Function(ParseResult result) onSave;
  final Future<void> Function(int exerciseId, String spoken) onAlias;
  final Duration? autoSaveAfter;

  @override
  State<ConfirmCard> createState() => _ConfirmCardState();
}

class _ConfirmCardState extends State<ConfirmCard> {
  Timer? _timer;
  var _saved = false;

  @override
  void initState() {
    super.initState();
    final delay = widget.autoSaveAfter;
    if (delay != null) {
      _timer = Timer(delay, _save);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _hold() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _save() async {
    if (_saved) {
      return;
    }
    _saved = true;
    _timer?.cancel();
    await widget.onSave(widget.result);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey('confirm-card'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final session in widget.result.sessions) ...[
              Text(
                session.summary,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              if (session.type == 'gym')
                for (final set in session.sets) _setEditor(set),
              for (final block in session.blocks) _blockEditor(session, block),
              const SizedBox(height: 8),
            ],
            for (final plan in widget.result.plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  plan.summary,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconTip(
                  icon: Icons.close,
                  message: 'Discard',
                  onPressed: () {
                    _saved = true;
                    _timer?.cancel();
                    Navigator.of(context).pop();
                  },
                ),
                IconTip(
                  icon: Icons.check,
                  message: 'Save',
                  onPressed: _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _setEditor(ParsedSet set) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _field(set.exerciseName ?? '?', 'Exercise', () async {
            _hold();
            final picked = await _pickExercise(context, widget.exercises);
            if (picked == null) {
              return;
            }
            final spoken = set.spoken;
            final changed = picked.id != set.exerciseId;
            setState(() {
              set.exerciseId = picked.id;
              set.exerciseName = picked.name;
              set.unmatched = false;
              set.muscleGroups = picked.muscleGroups;
              set.category = picked.category;
            });
            if (changed && spoken.trim().isNotEmpty) {
              await widget.onAlias(picked.id, spoken);
            }
          }),
          if (set.sets != null)
            _field('${set.sets}', 'Sets', () async {
              _hold();
              final value = await _pickInt(context, set.sets ?? 1, 1, 20);
              if (value != null) {
                setState(() => set.sets = value);
              }
            }),
          if (set.reps != null)
            _field('${set.reps}', 'Reps', () async {
              _hold();
              final value = await _pickInt(context, set.reps ?? 1, 1, 50);
              if (value != null) {
                setState(() => set.reps = value);
              }
            }),
          if (set.bodyweight)
            _field('bodyweight', 'Load', () async {
              _hold();
              final value = await _pickDouble(context, 20, 2.5);
              if (value != null) {
                setState(() {
                  set.bodyweight = false;
                  set.weightKg = value;
                });
              }
            })
          else if (set.weightKg != null)
            _field('${fmtKg(set.weightKg!)} kg', 'Weight', () async {
              _hold();
              final value = await _pickDouble(context, set.weightKg ?? 20, 2.5);
              if (value != null) {
                setState(() => set.weightKg = value);
              }
            }),
          IconTip(
            icon: Icons.speed,
            message: _rirTip(set.rir),
            onPressed: () async {
              _hold();
              final value = await _pickRir(context, set.rir);
              if (value == null) {
                return;
              }
              setState(() => set.rir = value.rir);
            },
          ),
        ],
      ),
    );
  }

  Widget _blockEditor(ParsedSession session, ParsedBlock block) {
    final time = block.durationMin == null ? '?' : '${block.durationMin} min';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            block.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          _field(time, 'Duration', () async {
            _hold();
            final value = await _pickInt(context, block.durationMin ?? 5, 5, 180);
            if (value != null) {
              setState(() {
                block.durationMin = value;
                _syncSession(session);
              });
            }
          }),
          _field('RPE ${block.rpe}', 'RPE', () async {
            _hold();
            final value = await _pickInt(context, block.rpe, 1, 10);
            if (value != null) {
              setState(() => block.rpe = value);
            }
          }),
          Text(block.durationMin == null ? '?' : '${block.load.round()}'),
        ],
      ),
    );
  }

  void _syncSession(ParsedSession session) {
    if (session.blocks.isEmpty) {
      return;
    }
    if (session.blocks.any((block) => block.durationMin == null)) {
      session.durationMin = null;
      return;
    }
    session.durationMin = session.blocks.fold<int>(
      0,
      (sum, block) => sum + block.durationMin!,
    );
  }

  Widget _field(String text, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

Future<Exercise?> _pickExercise(BuildContext context, List<Exercise> exercises) {
  final grouped = <String, List<Exercise>>{};
  for (final exercise in exercises) {
    grouped.putIfAbsent(exercise.category, () => []).add(exercise);
  }
  return showDialog<Exercise>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 320,
        height: 420,
        child: ListView(
          children: [
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  _category(entry.key),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final exercise in entry.value)
                ListTile(
                  title: Text(exercise.name),
                  onTap: () => Navigator.pop(context, exercise),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

Future<int?> _pickInt(BuildContext context, int current, int min, int max) {
  var value = current.clamp(min, max);
  return showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTip(
                icon: Icons.remove,
                message: 'Less',
                onPressed: () => setLocal(() {
                  if (value > min) {
                    value -= 1;
                  }
                }),
              ),
              Text(
                '$value',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              IconTip(
                icon: Icons.add,
                message: 'More',
                onPressed: () => setLocal(() {
                  if (value < max) {
                    value += 1;
                  }
                }),
              ),
              IconTip(
                icon: Icons.check,
                message: 'Save',
                onPressed: () => Navigator.pop(context, value),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<double?> _pickDouble(BuildContext context, double current, double step) {
  var value = current;
  return showDialog<double>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTip(
                icon: Icons.remove,
                message: 'Less',
                onPressed: () => setLocal(() {
                  value = (value - step).clamp(0, 500);
                }),
              ),
              Text(
                fmtKg(value),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              IconTip(
                icon: Icons.add,
                message: 'More',
                onPressed: () => setLocal(() {
                  value = (value + step).clamp(0, 500);
                }),
              ),
              IconTip(
                icon: Icons.check,
                message: 'Save',
                onPressed: () => Navigator.pop(context, value),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _rirTip(int? rir) {
  if (rir == null) {
    return 'RIR';
  }
  if (rir >= 3) {
    return 'RIR 3+';
  }
  return 'RIR $rir';
}

class _RirChoice {
  const _RirChoice(this.rir);
  final int? rir;
}

Future<_RirChoice?> _pickRir(BuildContext context, int? current) {
  const choices = <(String, int?)>[
    ('0', 0),
    ('1', 1),
    ('2', 2),
    ('3+', 3),
    ('', null),
  ];
  return showDialog<_RirChoice>(
    context: context,
    builder: (context) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final choice in choices)
            ListTile(
              selected: choice.$2 == current || (choice.$2 == 3 && (current ?? -1) >= 3),
              title: Text(choice.$1.isEmpty ? '—' : choice.$1),
              onTap: () => Navigator.pop(context, _RirChoice(choice.$2)),
            ),
        ],
      ),
    ),
  );
}

String _category(String category) => switch (category) {
  'strength' => 'Strength',
  'cardio' => 'Cardio',
  'combat' => 'Combat',
  'mobility' => 'Mobility',
  _ => category,
};
