import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:eye_tracking_collection/core/constants/app_colors.dart';
import 'package:eye_tracking_collection/core/services/haptics_service.dart';
import 'package:eye_tracking_collection/core/services/tts_service.dart';
import 'package:eye_tracking_collection/models/user_profile.dart';
import 'package:eye_tracking_collection/services/firestore_service.dart';
import 'package:eye_tracking_collection/widgets/pulsing_target.dart';
import 'package:flutter/material.dart';

enum ExperimentPhase { guidelines, calibration, pulse, moving, done }
enum ExperimentMode { calibration, pulse, moving }

class CollectionGridArgs {
  const CollectionGridArgs({required this.profile, required this.languageCode});

  final UserProfile profile;
  final String languageCode;

  factory CollectionGridArgs.empty() => CollectionGridArgs(
        profile: const UserProfile(
          name: 'Guest',
          age: 0,
          blindnessType: 'Unknown',
          languageCode: 'en',
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
      _cameraController = CameraController(front, ResolutionPreset.low, enableAudio: false);
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // ignore camera setup errors in dev
    }
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
      _ColorRegion(label: 'red', color: Colors.red, alignment: Alignment.topLeft),
      _ColorRegion(label: 'yellow', color: Colors.yellow, alignment: Alignment.topCenter),
      _ColorRegion(label: 'green', color: Colors.green, alignment: Alignment.topRight),
      _ColorRegion(label: 'blue', color: Colors.blue, alignment: Alignment.bottomLeft),
      _ColorRegion(label: 'magenta', color: Colors.purpleAccent, alignment: Alignment.bottomCenter),
      _ColorRegion(label: 'cyan', color: Colors.cyan, alignment: Alignment.bottomRight),
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
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      _colorIndex++;
      _startCalibrationStep();
    });
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
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      _timer = Timer(const Duration(milliseconds: 500), () {
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
      _flushSamples();
      setState(() {});
      return;
    }
    final speedDurations = [600, 400, 200];
    final speedLabels = ['slow', 'medium', 'fast'];
    _tts.speak('Follow the moving point ${speedLabels[_movingSpeedIndex]}');
    _haptics.pulse();
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: speedDurations[_movingSpeedIndex]), (_) {
      final next = Random().nextInt(_regions.length);
      _currentGridIndex = next;
      final region = _regions[next];
      _recordSample(mode: ExperimentMode.moving, region: region, speedLabel: speedLabels[_movingSpeedIndex]);
      setState(() {});
    });
    Future.delayed(const Duration(seconds: 10), () {
      _timer?.cancel();
      _movingSpeedIndex++;
      _advanceMoving();
    });
  }

  void _recordSample({required ExperimentMode mode, required _ColorRegion region, String? speedLabel}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final target = _alignmentToNormalized(region.alignment);
    final sample = {
      'timestamp': now,
      'mode': mode.name,
      'color': region.label,
      'target': {'x': target.dx, 'y': target.dy},
      // TODO: wire MediaPipe gaze/pupil/headPose here
      'gaze': {'x': target.dx, 'y': target.dy},
      'pupil': {
        'left': {'x': target.dx, 'y': target.dy},
        'right': {'x': target.dx, 'y': target.dy},
      },
      'headPose': {'yaw': 0.0, 'pitch': 0.0, 'roll': 0.0},
      'blink': false,
      'confidence': 0.0,
      if (speedLabel != null) 'speed': speedLabel,
    };
    _pendingSamples.add(sample);
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
    final userId = widget.args.profile.name.isEmpty ? 'guest' : widget.args.profile.name;
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
    _cameraController?.dispose();
    _tts.dispose();
    _flushSamples();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = _regions[_currentGridIndex];
    const borderColor = Colors.tealAccent;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Collection')),
      body: Stack(
        children: [
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 260,
                    height: 340,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.black, Colors.black87]),
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
          Align(
            alignment: _gridPositions[_currentGridIndex],
            child: GestureDetector(
              onTap: _advanceGrid,
              child: PulsingTarget(color: region.color),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Text(_statusText(), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                if (_phase == ExperimentPhase.guidelines) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _headAligned ? _startExperiment : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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
                          side: const BorderSide(color: Colors.tealAccent, width: 2),
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
  _ColorRegion({required this.label, required this.color, required this.alignment});
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
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
