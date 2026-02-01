import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  Future<void> initialize(String languageCode) async {
    if (_isInitialized) return;

    try {
      await _tts.setLanguage(languageCode);
      await _tts.setSpeechRate(0.5); // Slower for partially blind users
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _isInitialized = true;
      debugPrint('✓ TTS initialized: $languageCode');
    } catch (e) {
      debugPrint('❌ TTS initialization error: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize('en-US');
    }

    try {
      await _tts.speak(text);
      debugPrint('🔊 TTS: $text');
    } catch (e) {
      debugPrint('❌ TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('❌ TTS stop error: $e');
    }
  }

  void dispose() {
    _tts.stop();
  }
}
