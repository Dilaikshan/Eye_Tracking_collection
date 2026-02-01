import 'package:vibration/vibration.dart';
import 'package:flutter/material.dart';

class HapticsService {
  Future<void> pulse() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 100);
      }
    } catch (e) {
      debugPrint('❌ Haptics error: $e');
    }
  }

  Future<void> doublePulse() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 100);
        await Future.delayed(const Duration(milliseconds: 100));
        await Vibration.vibrate(duration: 100);
      }
    } catch (e) {
      debugPrint('❌ Haptics error: $e');
    }
  }

  Future<void> longPulse() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 300);
      }
    } catch (e) {
      debugPrint('❌ Haptics error: $e');
    }
  }
}
