import 'package:vibration/vibration.dart';

class HapticsService {
  Future<void> pulse() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 50, amplitude: 180);
    }
  }
}
