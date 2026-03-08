class CollectionConstants {
  // Timing constants
  static const int calibrationDwellMs = 2000; // 2 seconds per target
  static const int pulseDurationMs = 1500; // 1.5 seconds visible
  static const int pulseBlankMs = 500; // 0.5 seconds blank
  static const int pulseRepeats = 3; // 3 rounds
  static const int movingSlowMs = 600; // Slow speed
  static const int movingMediumMs = 400; // Medium speed
  static const int movingFastMs = 200; // Fast speed
  static const int movingDurationSec = 30; // 30 seconds per speed

  // Azure sampling
  static const int azureSampleIntervalSec = 30; // Sample every 30 seconds

  // Camera settings
  static const int targetFrameRate = 30; // 30 FPS
  static const int batchSize = 30; // Flush every 30 samples

  // Quality thresholds
  static const double minConfidence = 0.6; // Minimum overall confidence
  static const double minIrisConfidence =
      0.7; // Minimum iris detection confidence

  // Grid positions
  static const List<String> colorLabels = [
    'red',
    'yellow',
    'green',
    'blue',
    'magenta',
    'cyan'
  ];
}
