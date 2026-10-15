import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/training.dart';
import '../services/checkin_parser.dart';
import '../services/dates.dart';
import '../services/speech_capture.dart';
import '../services/voice_log_flow.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_tip.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({
    super.key,
    required this.store,
    required this.slot,
    required this.speech,
    this.date,
  });

  final Store store;
  final String slot;
  final SpeechCapture speech;
  final DateTime? date;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  int soreness = 5;
  int energy = 5;
  int sleepQuality = 5;
  double sleepHours = 7;
  int mood = 5;
  int stress = 5;
  int sessionFeel = 5;
  int ateWell = 5;
  var listening = false;
  VoiceLogFlow? _flow;

  bool get morning => widget.slot == 'morning';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final existing = await widget.store.checkInOn(
      isoDate(widget.date ?? widget.store.now()),
      widget.slot,
    );
    if (!mounted || existing == null) {
      return;
    }
    setState(() {
      soreness = existing.soreness ?? soreness;
      energy = existing.energy ?? energy;
      sleepQuality = existing.sleepQuality ?? sleepQuality;
      sleepHours = existing.sleepHours ?? sleepHours;
      mood = existing.mood ?? mood;
      stress = existing.stress ?? stress;
      sessionFeel = existing.sessionFeel ?? sessionFeel;
      ateWell = existing.ateWell ?? ateWell;
    });
  }

  Future<void> _holdStart() async {
    _flow = VoiceLogFlow(
      onStop: () {
        widget.speech.stop();
      },
      onConfirm: _applyVoice,
    );
    setState(() => listening = true);
    try {
      await widget.speech.start(
        onText: (words, _) => _flow?.onSpeech(words),
      );
    } on Object {
      if (mounted) {
        setState(() => listening = false);
      }
    }
  }

  void _holdEnd() {
    _flow?.onRelease(_flow?.latest ?? '');
    setState(() => listening = false);
  }

  Future<void> _applyVoice(String transcript) async {
    final parsed = parseCheckIn(transcript);
    setState(() {
      listening = false;
      if (parsed.soreness != null) {
        soreness = parsed.soreness!;
      }
      if (parsed.energy != null) {
        energy = parsed.energy!;
      }
      if (parsed.sleepQuality != null) {
        sleepQuality = parsed.sleepQuality!;
      }
      if (parsed.sleepHours != null) {
        sleepHours = parsed.sleepHours!;
      }
      if (parsed.mood != null) {
        mood = parsed.mood!;
      }
      if (parsed.stress != null) {
        stress = parsed.stress!;
      }
      if (parsed.sessionFeel != null) {
        sessionFeel = parsed.sessionFeel!;
      }
      if (parsed.ateWell != null) {
        ateWell = parsed.ateWell!;
      }
    });
    await _save(transcript);
  }

  Future<void> _save([String? transcript]) async {
    final day = isoDate(widget.date ?? widget.store.now());
    await widget.store.saveCheckIn(
      CheckIn(
        date: day,
        slot: widget.slot,
        soreness: morning ? soreness : null,
        energy: energy,
        sleepQuality: morning ? sleepQuality : null,
        sleepHours: morning ? sleepHours : null,
        mood: morning ? mood : null,
        stress: stress,
        sessionFeel: morning ? null : sessionFeel,
        ateWell: morning ? null : ateWell,
        rawTranscript: transcript,
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(morning ? 'Morning' : 'Evening'),
        actions: [
          Tooltip(
            message: 'Speak',
            child: GestureDetector(
              onLongPressStart: (_) => _holdStart(),
              onLongPressEnd: (_) => _holdEnd(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  listening ? Icons.mic : Icons.mic_none,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
          IconTip(icon: Icons.check, message: 'Save', onPressed: () => _save()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (morning) ...[
            _slider('Soreness', soreness, (value) => soreness = value),
            _slider('Energy', energy, (value) => energy = value),
            _slider('Sleep quality', sleepQuality, (value) => sleepQuality = value),
            _hours(),
            _slider('Mood', mood, (value) => mood = value),
            _slider('Stress', stress, (value) => stress = value),
          ] else ...[
            _slider('Session feel', sessionFeel, (value) => sessionFeel = value),
            _slider('Ate well', ateWell, (value) => ateWell = value),
            _slider('Stress', stress, (value) => stress = value),
            _slider('Energy', energy, (value) => energy = value),
          ],
        ],
      ),
    );
  }

  Widget _slider(String label, int value, void Function(int value) assign) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 1,
                  max: 10,
                  divisions: 9,
                  value: value.toDouble(),
                  onChanged: (next) => setState(() => assign(next.round())),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$value',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hours() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sleep hours', style: TextStyle(fontWeight: FontWeight.w600)),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 0,
                  max: 12,
                  divisions: 24,
                  value: sleepHours.clamp(0, 12),
                  onChanged: (next) => setState(() => sleepHours = next),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  sleepHours.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
