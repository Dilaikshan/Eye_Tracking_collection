import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:eye_tracking_collection/core/constants/app_colors.dart';
import 'package:eye_tracking_collection/core/services/haptics_service.dart';
import 'package:eye_tracking_collection/core/services/tts_service.dart';
import 'package:eye_tracking_collection/models/user_profile.dart';
import 'package:eye_tracking_collection/models/eye_tracking_data.dart';
import 'package:eye_tracking_collection/services/firestore_service.dart';
import 'package:eye_tracking_collection/services/mediapipe_service.dart';
import 'package:eye_tracking_collection/services/mlkit_service.dart';
import 'package:eye_tracking_collection/services/azure_service.dart'
    hide AzureFaceData;
import 'package:eye_tracking_collection/services/data_fusion_service.dart';
import 'package:eye_tracking_collection/widgets/pulsing_target.dart';
import 'package:eye_tracking_collection/widgets/eye_tracking_overlay.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

enum ExperimentPhase { guidelines, calibration, pulse, moving, done }

enum ExperimentMode { calibration, pulse, moving }

class CollectionGridArgs {
  const CollectionGridArgs({required this.profile, required this.languageCode});

  final UserProfile profile;
  final String languageCode;

  factory CollectionGridArgs.empty() => CollectionGridArgs(
        profile: UserProfile(
          name: 'Guest',
          age: 0,
          blindnessType: 'Unknown',
          languageCode: 'en',
          dominantEye: 'both',
          visionAcuity: 5,
          wearsGlasses: false,
          consentGiven: false,
        ),
        languageCode: 'en',
      );
}

class CollectionGridScreen extends StatefulWidget {
  const CollectionGridScreen({super.key, required this.args});

  static const String routeName = '/collect';
  final CollectionGridArgs args;

  @override
  State<CollectionGridScreen> createState() => _CollectionGridScreenState();
}

class _CollectionGridScreenState extends State<CollectionGridScreen> {
  int _currentGridIndex = 0;
  Timer? _timer;
  CameraController? _cameraController;

  final List<Alignment> _gridPositions = const [
    Alignment.topLeft,
    Alignment.topCenter,
    Alignment.topRight,
    Alignment.bottomLeft,
    Alignment.bottomCenter,
    Alignment.bottomRight,
  ];

  ExperimentPhase _phase = ExperimentPhase.guidelines;
  final TtsService _tts = TtsService();
  final HapticsService _haptics = HapticsService();
  final FirestoreService _firestore = FirestoreService();

  // Eye tracking services
  final MediaPipeService _mediapipe = MediaPipeService();
  final MLKitService _mlkit = MLKitService();
  final AzureFaceService _azure = AzureFaceService();
  final DataFusionService _fusion = DataFusionService();

  // Current eye tracking data
  MediaPipeIrisData? _currentMediaPipeData;
  MLKitFaceData? _currentMLKitData;
  AzureFaceData? _currentAzureData;

  final List<Map<String, dynamic>> _pendingSamples = [];
  int _chunkIndex = 0;
  String? _sessionId;
  late List<_ColorRegion> _regions;
  int _colorIndex = 0;
  int _pulseRepeat = 0;
  int _movingSpeedIndex = 0;
  bool _headSizeCalibrated = false;
  bool _headAligned = false;
  bool _alignmentManuallySet = false;

  // Timer tracking
  int _remainingSeconds = 0;
  Timer? _countdownTimer;

  // Moving pattern tracking
  int _lineStepIndex = 0;
  bool _showCamera = true;

  @override
  void initState() {
    super.initState();
    _regions = _buildRegions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapSession());
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController =
          CameraController(front, ResolutionPreset.low, enableAudio: false);
      await _cameraController!.initialize();
      if (!mounted) return;

      // Start camera stream for eye tracking
      _startCameraStream();

      setState(() {});
    } catch (_) {
      // ignore camera setup errors in dev
    }
  }

  void _startCameraStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    _cameraController!.startImageStream((CameraImage image) async {
      // Get rotation based on device orientation
      final rotation = _getImageRotation();

      // Process with MediaPipe and ML Kit in parallel (fast, on-device)
      // Skip Azure for real-time processing (too slow)
      final futures = await Future.wait([
        _mediapipe.processImage(image, rotation),
        _mlkit.processImage(image, rotation),
      ]);

      _currentMediaPipeData = futures[0] as MediaPipeIrisData?;
      _currentMLKitData = futures[1] as MLKitFaceData?;

      // Optional: Call Azure periodically (every 30 frames) for validation
      // _currentAzureData remains null for now - Azure is called during batch upload
    });
  }

  InputImageRotation _getImageRotation() {
    // Simplified - assumes portrait mode
    // TODO: Handle device rotation properly
    return InputImageRotation.rotation0deg;
  }

  Future<void> _bootstrapSession() async {
    final size = MediaQuery.of(context).size;
    _sessionId = await _firestore.startSession(
      profile: widget.args.profile,
      screenSize: size,
      consentGiven: true,
    );
    await _speakGuidelines();
    await _calibrateHeadSize();
  }

  Future<void> _calibrateHeadSize() async {
    await _tts.speak('Align your head to the frame. Keep still.');
    await Future.delayed(const Duration(seconds: 2));
    _headSizeCalibrated = true;
    // Keep red until user confirms alignment.
    setState(() {});
  }

  List<_ColorRegion> _buildRegions() {
    return [
      _ColorRegion(
          label: 'red', color: Colors.red, alignment: Alignment.topLeft),
      _ColorRegion(
          label: 'yellow',
          color: Colors.yellow,
          alignment: Alignment.topCenter),
      _ColorRegion(
          label: 'green', color: Colors.green, alignment: Alignment.topRight),
      _ColorRegion(
          label: 'blue', color: Colors.blue, alignment: Alignment.bottomLeft),
      _ColorRegion(
          label: 'magenta',
          color: Colors.purpleAccent,
          alignment: Alignment.bottomCenter),
      _ColorRegion(
          label: 'cyan', color: Colors.cyan, alignment: Alignment.bottomRight),
    ];
  }

  Future<void> _speakGuidelines() async {
    const lines = [
      'Hold the phone at chest level or place it on a stable surface.',
      'Ensure your face is visible to the front camera.',
      'Avoid strong light behind you.',
      'Follow voice instructions carefully.',
      'Only eye and head coordinates are collected. No video is stored.',
    ];
    for (final line in lines) {
      await _tts.speak(line);
    }
  }

  void _startExperiment() {
    if (!_headSizeCalibrated || !_headAligned) return;
    _phase = ExperimentPhase.calibration;
    _colorIndex = 0;
    _pulseRepeat = 0;
    _showCamera = false; // Hide camera during data collection
    _startCalibrationStep();
    setState(() {});
  }

  void _startCalibrationStep() {
    if (_colorIndex >= _regions.length) {
      _phase = ExperimentPhase.pulse;
      _colorIndex = 0;
      _pulseRepeat = 0;
      _startPulse();
      return;
    }
    final region = _regions[_colorIndex];
    _tts.speak('Look at the ${region.label} area');
    _haptics.pulse();
    _recordSample(mode: ExperimentMode.calibration, region: region);

    // Start countdown
    _remainingSeconds = 2;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      _countdownTimer?.cancel();
      _colorIndex++;
      _startCalibrationStep();
    });
    setState(() {});
  }

  void _startPulse() {
    if (_pulseRepeat >= 3) {
      _phase = ExperimentPhase.moving;
      _colorIndex = 0;
      _startMovingPhase();
      setState(() {});
      return;
    }
    if (_colorIndex >= _regions.length) {
      _colorIndex = 0;
      _pulseRepeat++;
    }
    final region = _regions[_colorIndex];
    _tts.speak('Look at the ${region.label} color');
    _haptics.pulse();
    _recordSample(mode: ExperimentMode.pulse, region: region);

    // Start countdown (2 seconds total: 1.5s visible + 0.5s gap)
    _remainingSeconds = 2;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });

    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      _timer = Timer(const Duration(milliseconds: 500), () {
        _countdownTimer?.cancel();
        _colorIndex++;
        _startPulse();
      });
    });
    setState(() {});
  }

  void _startMovingPhase() {
    _movingSpeedIndex = 0;
    _advanceMoving();
  }

  void _advanceMoving() {
    if (_movingSpeedIndex >= 3) {
      _phase = ExperimentPhase.done;
      _timer?.cancel();
      _countdownTimer?.cancel();
      _flushSamples();
      setState(() {});
      return;
    }

    // Slower speeds: 1200ms, 800ms, 500ms (instead of 600, 400, 200)
    final speedDurations = [1200, 800, 500];
    final speedLabels = ['slow', 'medium', 'fast'];

    // Line patterns: horizontal top, horizontal bottom, vertical, diagonal
    final linePatterns = [
      [0, 1, 2], // Top row: left -> center -> right
      [2, 1, 0], // Top row reverse
      [3, 4, 5], // Bottom row: left -> center -> right
      [5, 4, 3], // Bottom row reverse
      [0, 3], // Left column: top -> bottom
      [3, 0], // Left column reverse
      [2, 5], // Right column: top -> bottom
      [5, 2], // Right column reverse
      [0, 1, 2, 5, 4, 3], // U-shape
      [0, 4, 2], // Diagonal pattern
    ];

    _tts.speak('Follow the moving point ${speedLabels[_movingSpeedIndex]}');
    _haptics.pulse();

    // Start 15-second countdown (increased from 10)
    _remainingSeconds = 15;
    _lineStepIndex = 0;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });

    // Select a random pattern for variety
    final pattern = linePatterns[Random().nextInt(linePatterns.length)];

    _timer?.cancel();
    _timer = Timer.periodic(
        Duration(milliseconds: speedDurations[_movingSpeedIndex]), (_) {
      // Follow the line pattern
      final next = pattern[_lineStepIndex % pattern.length];
      _currentGridIndex = next;
      _colorIndex = next;
      final region = _regions[next];
      _recordSample(
          mode: ExperimentMode.moving,
          region: region,
          speedLabel: speedLabels[_movingSpeedIndex]);
      _lineStepIndex++;
      setState(() {});
    });

    Future.delayed(const Duration(seconds: 15), () {
      _timer?.cancel();
      _countdownTimer?.cancel();
      _movingSpeedIndex++;
      _advanceMoving();
    });
  }

  void _recordSample(
      {required ExperimentMode mode,
      required _ColorRegion region,
      String? speedLabel}) {
    final target = _alignmentToNormalized(region.alignment);

    // Fuse data from all sources
    final eyeData = _fusion.fuseData(
      target: target,
      mode: mode.name,
      colorLabel: region.label,
      mediapipe: _currentMediaPipeData,
      mlkit: _currentMLKitData,
      azure: _currentAzureData, // Usually null during real-time collection
      speedLabel: speedLabel,
    );

    // Skip samples with low confidence (below 60%)
    if (eyeData.overallConfidence < 0.6) {
      debugPrint(
          'Skipping sample - low confidence: ${eyeData.overallConfidence}');
      return;
    }

    // Convert to Firestore format
    _pendingSamples.add(eyeData.toFirestore());

    if (_pendingSamples.length >= 30) {
      _flushSamples();
    }
  }

  Offset _alignmentToNormalized(Alignment alignment) {
    final x = (alignment.x + 1) / 2;
    final y = (alignment.y + 1) / 2;
    return Offset(x, y);
  }

  Future<void> _flushSamples() async {
    if (_sessionId == null || _pendingSamples.isEmpty) return;
    final userId =
        widget.args.profile.name.isEmpty ? 'guest' : widget.args.profile.name;
    await _firestore.addSamples(
      userId: userId,
      sessionId: _sessionId!,
      samples: List<Map<String, dynamic>>.from(_pendingSamples),
      chunkIndex: _chunkIndex,
    );
    _chunkIndex++;
    _pendingSamples.clear();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _mediapipe.dispose();
    _mlkit.dispose();
    _tts.dispose();
    _flushSamples();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = _regions[_currentGridIndex];
    const borderColor = Colors.tealAccent;

    // Calculate fused gaze for overlay
    Offset? fusedGaze;
    if (_currentMediaPipeData != null &&
        _currentMediaPipeData!.leftEyeOpen &&
        _currentMediaPipeData!.rightEyeOpen) {
      fusedGaze = Offset(
        (_currentMediaPipeData!.leftIrisCenter.dx +
                _currentMediaPipeData!.rightIrisCenter.dx) /
            2,
        (_currentMediaPipeData!.leftIrisCenter.dy +
                _currentMediaPipeData!.rightIrisCenter.dy) /
            2,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Collection')),
      body: Stack(
        children: [
          if (_showCamera &&
              _cameraController != null &&
              _cameraController!.value.isInitialized)
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 260,
                    height: 340,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Colors.black, Colors.black87]),
                      border: Border.all(
                        color: borderColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: borderColor.withOpacity(0.6),
                          blurRadius: 24,
                          spreadRadius: 8,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                  // Alignment guide lines (crosshair)
                  IgnorePointer(
                    ignoring: true,
                    child: SizedBox(
                      width: 240,
                      height: 320,
                      child: CustomPaint(
                        painter: _GuidePainter(color: borderColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Eye tracking overlay (only show during data collection)
          if (_phase != ExperimentPhase.guidelines)
            EyeTrackingOverlay(
              mediapipeData: _currentMediaPipeData,
              mlkitData: _currentMLKitData,
              azureData: _currentAzureData,
              fusedGaze: fusedGaze,
              showOverlay: true,
            ),
          Align(
            alignment: _regions[_colorIndex % _regions.length].alignment,
            child: GestureDetector(
              onTap: _advanceGrid,
              child: PulsingTarget(
                  color: _regions[_colorIndex % _regions.length].color),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Text(_statusText(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                if (_phase != ExperimentPhase.guidelines &&
                    _phase != ExperimentPhase.done)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.tealAccent, width: 2),
                    ),
                    child: Text(
                      'Time remaining: $_remainingSeconds seconds',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_phase == ExperimentPhase.guidelines) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _headAligned ? _startExperiment : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 24),
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          shadowColor: Colors.tealAccent,
                          elevation: 8,
                        ),
                        child: const Text('Start Data Collection'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _alignmentManuallySet ? null : _markAligned,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.tealAccent,
                          side: const BorderSide(
                              color: Colors.tealAccent, width: 2),
                        ),
                        child: const Text('I am aligned'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Participant: ${widget.args.profile.name}, ${widget.args.profile.blindnessType}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _advanceGrid() {
    switch (_phase) {
      case ExperimentPhase.guidelines:
        _startExperiment();
        break;
      case ExperimentPhase.calibration:
        _colorIndex++;
        _startCalibrationStep();
        break;
      case ExperimentPhase.pulse:
        _colorIndex++;
        _startPulse();
        break;
      case ExperimentPhase.moving:
        // manual tap: jump to next random region
        _currentGridIndex = Random().nextInt(_regions.length);
        setState(() {});
        break;
      case ExperimentPhase.done:
        break;
    }
  }

  void _markAligned() {
    _headAligned = true;
    _alignmentManuallySet = true;
    setState(() {});
  }

  String _statusText() {
    switch (_phase) {
      case ExperimentPhase.guidelines:
        return 'Position your face in the frame and press "I am aligned" when ready';
      case ExperimentPhase.calibration:
        return 'Calibration: focus on ${_regions[_colorIndex % _regions.length].label}';
      case ExperimentPhase.pulse:
        return 'Static color pulse: ${_regions[_colorIndex % _regions.length].label}';
      case ExperimentPhase.moving:
        return 'Moving point';
      case ExperimentPhase.done:
        return 'Session complete';
    }
  }
}

class _ColorRegion {
  _ColorRegion(
      {required this.label, required this.color, required this.alignment});
  final String label;
  final Color color;
  final Alignment alignment;
}

class _GuidePainter extends CustomPainter {
  _GuidePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, paint);
    // crosshair lines
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
