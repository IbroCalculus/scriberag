import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (val) => print('Speech initialization error: $val'),
        onStatus: (val) => print('Speech initialization status: $val'),
      );
      return _isInitialized;
    } catch (e) {
      print('Speech service initialization failed: $e');
      _isInitialized = false;
      return false;
    }
  }

  bool get isAvailable => _isInitialized;
  bool get isListening => _speech.isListening;

  Future<void> startListening({
    required Function(String text) onResult,
  }) async {
    if (!_isInitialized) {
      final ok = await init();
      if (!ok) {
        throw Exception("Speech recognition not available or permission denied");
      }
    }

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      listenFor: const Duration(minutes: 10),
      pauseFor: const Duration(seconds: 15),
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
