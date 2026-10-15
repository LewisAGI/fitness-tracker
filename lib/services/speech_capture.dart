import 'package:speech_to_text/speech_to_text.dart';

class SpeechCapture {
  SpeechCapture({SpeechToText? speech}) : _injected = speech;

  final SpeechToText? _injected;
  SpeechToText? _owned;

  SpeechToText get _speech => _injected ?? (_owned ??= SpeechToText());

  bool available = false;
  bool initialised = false;

  bool get isListening => _speech.isListening;

  Future<bool> ensureReady() async {
    if (initialised) {
      return available;
    }
    try {
      available = await _speech.initialize(onError: (_) {}, onStatus: (_) {});
    } on Object {
      available = false;
    }
    initialised = true;
    return available;
  }

  Future<void> start({
    required void Function(String words, bool finalResult) onText,
  }) async {
    final ready = await ensureReady();
    if (!ready) {
      throw StateError('Speech recognition is not available.');
    }
    await _speech.listen(
      onResult: (result) {
        onText(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        localeId: 'en_GB',
        partialResults: true,
        cancelOnError: true,
        onDevice: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();
}
