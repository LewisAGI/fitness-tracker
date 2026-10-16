import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/training.dart';
import '../services/dates.dart';
import '../services/speech_capture.dart';
import '../services/voice_log_flow.dart';
import '../services/voice_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_action.dart';
import '../widgets/confirm_card.dart';
import '../widgets/rest_pill.dart';
import '../widgets/set_log.dart';
import '../widgets/share_deck.dart';
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
          Tooltip(
            message: 'Log',
            child: GestureDetector(
              key: const ValueKey('mic'),
              onLongPressStart: (_) => _holdStart(),
              onLongPressEnd: (_) => _holdEnd(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.mic,
                  color: _listening ? AppColors.accentPressed : AppColors.accent,
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('share'),
            tooltip: 'Share',
            onPressed: () => showShareDeck(context, widget.store),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          Text(
            fmtWeekdayDate(today),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
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
              SetLog(
                session: session,
                goals: widget.store.goals,
                store: widget.store,
                onEdit: () => _edit(session),
                onDelete: () => _delete(session),
              ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const RestPill(),
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
