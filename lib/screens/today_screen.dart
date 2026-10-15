import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/training.dart';
import '../services/dates.dart';
import '../services/share_export.dart';
import '../services/speech_capture.dart';
import '../services/voice_log_flow.dart';
import '../services/voice_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_action.dart';
import '../widgets/confirm_card.dart';
import '../widgets/icon_tip.dart';
import '../widgets/pace_flag.dart';
import 'checkin_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.store,
    required this.speech,
  });

  final Store store;
  final SpeechCapture speech;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DayBundle? _day;
  var _listening = false;
  VoiceLogFlow? _flow;

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
    final day = await widget.store.loadDay(widget.store.now());
    if (mounted) {
      setState(() => _day = day);
    }
  }

  Future<void> _holdStart() async {
    final last = await widget.store.lastExercise();
    _flow = VoiceLogFlow(
      onStop: () {
        widget.speech.stop();
      },
      onConfirm: (text) => _confirm(text, last),
    );
    setState(() => _listening = true);
    try {
      await widget.speech.start(
        onText: (words, isFinal) => _flow?.onSpeech(words, isFinal: isFinal),
      );
    } on Object {
      if (mounted) {
        setState(() => _listening = false);
      }
    }
  }

  void _holdEnd() {
    _flow?.onRelease(_flow?.latest ?? '');
    if (mounted) {
      setState(() => _listening = false);
    }
  }

  Future<void> _confirm(String text, Exercise? last) async {
    if (mounted) {
      setState(() => _listening = false);
    }
    final parser = VoiceParser(
      widget.store.exercises,
      roundMinutes: widget.store.roundMinutes,
    );
    final result = parser.parse(text, lastExercise: last);
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => ConfirmCard(
        result: result,
        exercises: widget.store.exercises,
        onAlias: widget.store.addAlias,
        onSave: (draft) => widget.store.saveParse(draft),
      ),
    );
  }

  Future<void> _edit(Session session) async {
    final result = sessionToParseResult(session);
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => ConfirmCard(
        result: result,
        exercises: widget.store.exercises,
        onAlias: widget.store.addAlias,
        onSave: (draft) => widget.store.replaceSession(session.id, draft),
        autoSaveAfter: null,
      ),
    );
  }

  Future<void> _delete(Session session) async {
    final ok = await confirmChoice(context);
    if (!ok) {
      return;
    }
    await widget.store.deleteSession(session.id);
  }

  Future<void> _export(String kind) async {
    final today = dateOnly(widget.store.now());
    final DateTime start;
    final DateTime end;
    if (kind == 'day') {
      start = today;
      end = today;
    } else if (kind == 'week') {
      start = weekStart(today);
      end = start.add(const Duration(days: 6));
    } else {
      start = DateTime(today.year, today.month);
      end = DateTime(today.year, today.month + 1, 0);
    }
    final files = await widget.store.exportRange(
      start: start,
      end: end,
      kind: kind,
    );
    if (!mounted) {
      return;
    }
    await offerExport(context, files);
  }

  Future<void> _exportSession(Session session) async {
    final files = await widget.store.exportSession(session);
    if (!mounted) {
      return;
    }
    await offerExport(context, files);
  }

  void _openCheckIn(String slot) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CheckInScreen(
          store: widget.store,
          slot: slot,
          speech: widget.speech,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    final today = widget.store.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey('export-menu'),
            tooltip: 'Export',
            onSelected: _export,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'day', child: Text('Day')),
              PopupMenuItem(value: 'week', child: Text('Week')),
              PopupMenuItem(value: 'month', child: Text('Month')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          Text(
            fmtWeekdayDate(today),
            style: const TextStyle(fontSize: 16, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _status(
                key: const ValueKey('morning-status'),
                icon: day?.morning == null
                    ? Icons.wb_sunny_outlined
                    : Icons.wb_sunny,
                message: 'Morning',
                done: day?.morning != null,
                onTap: () => _openCheckIn('morning'),
              ),
              _status(
                key: const ValueKey('evening-status'),
                icon: day?.evening == null
                    ? Icons.nightlight_outlined
                    : Icons.nightlight,
                message: 'Evening',
                done: day?.evening != null,
                onTap: () => _openCheckIn('evening'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (day != null)
            for (final plan in day.plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  planLine(plan),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          if (day != null)
            for (final session in day.sessions)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.hairline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sessionLine(session),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        PaceFlagIcon(
                          session: session,
                          goals: widget.store.goals,
                        ),
                        IconTip(
                          icon: Icons.ios_share,
                          message: 'Export',
                          compact: true,
                          onPressed: () => _exportSession(session),
                        ),
                        IconTip(
                          icon: Icons.edit_outlined,
                          message: 'Edit',
                          compact: true,
                          onPressed: () => _edit(session),
                        ),
                        IconTip(
                          icon: Icons.delete_outline,
                          message: 'Delete',
                          compact: true,
                          onPressed: () => _delete(session),
                        ),
                      ],
                    ),
                    for (final block in session.blocks)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${block.label ?? _block(block.subtype)} · ${block.durationMin == null ? '?' : '${block.durationMin} min'} · RPE ${block.rpe}',
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Tooltip(
        message: 'Log',
        child: GestureDetector(
          key: const ValueKey('mic'),
          onLongPressStart: (_) => _holdStart(),
          onLongPressEnd: (_) => _holdEnd(),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _listening ? AppColors.accentPressed : AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }

  Widget _status({
    required Key key,
    required IconData icon,
    required String message,
    required bool done,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: message,
      child: IconButton(
        key: key,
        onPressed: onTap,
        icon: Icon(
          icon,
          color: done ? AppColors.accent : AppColors.muted,
          size: 28,
        ),
      ),
    );
  }
}

String _block(String subtype) => switch (subtype) {
  'technique' => 'Technique',
  'pads' => 'Pads',
  'clinch' => 'Clinch',
  'sparring' => 'Sparring',
  'conditioning' => 'Conditioning',
  'other' => 'Other',
  _ => subtype,
};
