import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) {
        _isListening = false;
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
    );
    return _isInitialized;
  }

  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    _isListening = true;
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: 'id_ID',
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
  }

  Future<void> cancel() async {
    _isListening = false;
    await _speech.cancel();
  }

  void dispose() {
    _speech.cancel();
  }
}
