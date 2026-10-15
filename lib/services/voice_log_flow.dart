import 'voice_end_word.dart';

/// Hold-to-talk log. "done" / "I'm done" stops listening and opens confirm.
class VoiceLogFlow {
  VoiceLogFlow({required this.onStop, required this.onConfirm});

  final void Function() onStop;
  final void Function(String transcript) onConfirm;

  bool finished = false;
  String latest = '';

  void onSpeech(String transcript) {
    latest = transcript;
    if (finished) {
      return;
    }
    if (VoiceEndWord.endsLog(transcript)) {
      _finish(transcript);
    }
  }

  void onRelease(String transcript) {
    if (transcript.trim().isNotEmpty) {
      latest = transcript;
    }
    if (finished) {
      return;
    }
    if (latest.trim().isEmpty) {
      finished = true;
      onStop();
      return;
    }
    _finish(latest);
  }

  void _finish(String transcript) {
    finished = true;
    onStop();
    onConfirm(VoiceEndWord.strip(transcript));
  }
}
