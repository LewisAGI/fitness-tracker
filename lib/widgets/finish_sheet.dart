import 'package:flutter/material.dart';

import '../models/training.dart';
import '../theme/app_theme.dart';
import 'icon_tip.dart';

Future<void> showFinishSheet(
  BuildContext context, {
  required Session session,
  required Future<void> Function(int rpe) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.canvas,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      final maxHeight = MediaQuery.sizeOf(context).height * 0.62;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: _FinishSheet(session: session, onSave: onSave),
        ),
      );
    },
  );
}

class _FinishSheet extends StatefulWidget {
  const _FinishSheet({required this.session, required this.onSave});

  final Session session;
  final Future<void> Function(int rpe) onSave;

  @override
  State<_FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends State<_FinishSheet> {
  late int _rpe = widget.session.rpe ?? 6;

  @override
  Widget build(BuildContext context) {
    final name = widget.session.sets
        .map((set) => set.exerciseName)
        .whereType<String>()
        .toSet()
        .join(', ');
    return Padding(
      key: const ValueKey('finish-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: IconTip(
              icon: Icons.close,
              message: 'Close',
              compact: true,
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            ),
          ),
          Text(
            name.isEmpty ? 'Workout' : name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_rpe',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              color: AppColors.ink,
            ),
          ),
          Slider(
            value: _rpe.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (value) => setState(() => _rpe = value.round()),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconTip(
              icon: Icons.check,
              message: 'Save',
              onPressed: () async {
                final rpe = _rpe;
                Navigator.of(context, rootNavigator: true).pop();
                await widget.onSave(rpe);
              },
            ),
          ),
        ],
      ),
    );
  }
}
