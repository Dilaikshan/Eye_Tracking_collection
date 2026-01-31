import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService() : _tts = FlutterTts();

  final FlutterTts _tts;

  Future<void> speak(String text, {String languageCode = 'en-US'}) async {
    await _tts.setLanguage(languageCode);
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
