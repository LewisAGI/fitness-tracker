import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/training.dart';
import '../services/checkin_scheduler.dart';
import '../services/dates.dart';
import '../theme/app_theme.dart';
import '../widgets/goals_editor.dart';
import '../widgets/icon_tip.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    required this.scheduler,
  });

  final Store store;
  final CheckInScheduler scheduler;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  Future<void> _apply(CheckInSchedule next) async {
    final current = widget.store.schedule;
    final enabling =
        (!current.morningEnabled && next.morningEnabled) ||
        (!current.eveningEnabled && next.eveningEnabled);
    if (enabling) {
      final allowed = await widget.scheduler.requestPermissions();
      if (!allowed) {
        await widget.store.setNotificationsDenied(true);
        return;
      }
    }
    if (enabling && widget.store.notificationsDenied) {
      await widget.store.setNotificationsDenied(false);
    }
    await widget.store.setSchedule(next);
    await widget.scheduler.reschedule(next);
  }

  Future<void> _pickTime({required bool morning}) async {
    final schedule = widget.store.schedule;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: morning ? schedule.morningHour : schedule.eveningHour,
        minute: morning ? schedule.morningMinute : schedule.eveningMinute,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) {
      return;
    }
    await _apply(
      morning
          ? schedule.copyWith(morningHour: picked.hour, morningMinute: picked.minute)
          : schedule.copyWith(eveningHour: picked.hour, eveningMinute: picked.minute),
    );
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) {
      return;
    }
    final text = await File(path).readAsString();
    try {
      await widget.store.importSummary(text);
    } on FormatException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Icon(Icons.error_outline, color: AppColors.accent),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.store.schedule;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconTip(
            icon: Icons.track_changes,
            message: 'Goals',
            onPressed: () => showGoalsEditor(context, widget.store),
          ),
          IconTip(
            icon: Icons.file_download_outlined,
            message: 'Import',
            onPressed: _import,
          ),
        ],
      ),
      body: ListView(
        children: [
          _row(
            icon: Icons.wb_sunny_outlined,
            message: 'Morning',
            enabled: schedule.morningEnabled,
            time: fmtHm(schedule.morningHour, schedule.morningMinute),
            onToggle: (value) => _apply(schedule.copyWith(morningEnabled: value)),
            onTime: () => _pickTime(morning: true),
          ),
          _row(
            icon: Icons.nightlight_outlined,
            message: 'Evening',
            enabled: schedule.eveningEnabled,
            time: fmtHm(schedule.eveningHour, schedule.eveningMinute),
            onToggle: (value) => _apply(schedule.copyWith(eveningEnabled: value)),
            onTime: () => _pickTime(morning: false),
          ),
          ListTile(
            leading: IconTip(
              icon: Icons.timer_outlined,
              message: '${widget.store.roundMinutes} min',
              onPressed: _pickRound,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.list, color: AppColors.accent),
            title: const Text('Exercises'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => _Dictionary(store: widget.store),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String message,
    required bool enabled,
    required String time,
    required ValueChanged<bool> onToggle,
    required VoidCallback onTime,
  }) {
    return ListTile(
      leading: Tooltip(
        message: message,
        child: Icon(icon, color: enabled ? AppColors.accent : AppColors.muted),
      ),
      title: Switch(
        key: ValueKey('$message-switch'),
        value: enabled,
        onChanged: onToggle,
      ),
      trailing: IconTip(
        icon: Icons.schedule,
        message: time,
        onPressed: onTime,
      ),
    );
  }

  Future<void> _pickRound() async {
    var value = widget.store.roundMinutes;
    final picked = await showDialog<int>(
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
                    if (value > 1) {
                      value -= 1;
                    }
                  }),
                ),
                Text(
                  '$value',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                ),
                IconTip(
                  icon: Icons.add,
                  message: 'More',
                  onPressed: () => setLocal(() {
                    if (value < 15) {
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
    if (picked != null) {
      await widget.store.setRoundMinutes(picked);
    }
  }
}

class _Dictionary extends StatelessWidget {
  const _Dictionary({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final exercises = [...store.exercises]
      ..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body: ListView(
        children: [
          for (final exercise in exercises)
            ListTile(
              title: Text(exercise.name),
              subtitle: exercise.aliases.isEmpty
                  ? null
                  : Text(exercise.aliases.join(', ')),
              onTap: () => _edit(context, exercise),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, Exercise exercise) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final alias in exercise.aliases) Text(alias),
              Row(
                children: [
                  Expanded(child: TextField(controller: controller)),
                  IconTip(
                    icon: Icons.add,
                    message: 'Add',
                    onPressed: () async {
                      await store.addAlias(exercise.id, controller.text);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }
}
