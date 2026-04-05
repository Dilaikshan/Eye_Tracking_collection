import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:eye_tracking_collection/core/constants/app_colors.dart';
import 'package:eye_tracking_collection/core/constants/collection_constants.dart';
import 'package:eye_tracking_collection/core/services/haptics_service.dart';
import 'package:eye_tracking_collection/core/services/tts_service.dart';
import 'package:eye_tracking_collection/models/user_profile.dart';
import 'package:eye_tracking_collection/models/eye_tracking_data.dart';
import 'package:eye_tracking_collection/models/mediapipe_data.dart';
import 'package:eye_tracking_collection/models/mlkit_data.dart';
import 'package:eye_tracking_collection/models/eye_tracking_sample.dart';
import 'package:eye_tracking_collection/screens/diagnostic_screen.dart';
import 'package:eye_tracking_collection/screens/session_summary_screen.dart';
import 'package:eye_tracking_collection/services/firestore_service.dart';
import 'package:eye_tracking_collection/services/eye_crop_service.dart';
import 'package:eye_tracking_collection/services/mediapipe_service.dart';
import 'package:eye_tracking_collection/services/mlkit_service.dart';
import 'package:eye_tracking_collection/widgets/pulsing_target.dart';
import 'package:eye_tracking_collection/widgets/eye_tracking_overlay.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart'
    show InputImageRotation;
import 'package:uuid/uuid.dart';

enum ExperimentPhase { guidelines, calibration, pulse, moving, done }

enum ExperimentMode { calibration, pulse, moving }

class CollectionGridArgs {
  const CollectionGridArgs({required this.profile, required this.languageCode});

  final UserProfile profile;
  final String languageCode;

  factory CollectionGridArgs.empty() => CollectionGridArgs(
        profile: UserProfile(
          personId: 'P-GUEST',
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
  Timer? _timer;
  CameraController? _cameraController;

  // Time to wait after DiagnosticScreen closes before re-opening the camera.
  // DiagnosticScreen.dispose() calls stopImageStream/dispose without await
  // (unavoidable in Flutter), so we need to give the OS enough time to fully
  // release the camera hardware. 500 ms is sufficient on most Android devices.
  static const Duration _cameraReleaseDelay = Duration(milliseconds: 500);

  ExperimentPhase _phase = ExperimentPhase.guidelines;
  final TtsService _tts = TtsService();
  final HapticsService _haptics = HapticsService();
  final FirestoreService _firestore = FirestoreService();

  // Eye tracking services
  final MediaPipeService _mediapipe = MediaPipeService();
  final MLKitService _mlkit = MLKitService();
  final _uuid = const Uuid();

  // Current eye tracking data (raw from camera stream)
  MediaPipeIrisData? _currentMediaPipeData;
  MLKitFaceData? _currentMLKitData;
  CameraImage? _latestCameraImage;

  MediaPipeData? _overlayMediaPipeData;
  MLKitData? _overlayMLKitData;
  Size _cameraImageSize = Size.zero;
  bool _showEyeTrackingOverlay = true;

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
  DateTime? _lastDetectionTime;
  static const Duration _detectionHoldDuration = Duration(milliseconds: 600);
  int _frameSkipCounter = 0;
  static const int _frameSkipInterval = 3;
  int _consecutiveDetectionFrames = 0;
  static const int _autoAlignFrameThreshold = 20;

  // Timer tracking
  int _remainingSeconds = 0;
  Timer? _countdownTimer;

  // Moving pattern tracking
  int _lineStepIndex = 0;

  // ── Quality bar & sample counter ────────────────────────────────────────────
  int _totalSamplesCollected = 0;
  double _lastConfidence = 0.0;
  double _lastLeftEAR = 0.0;
  double _lastRightEAR = 0.0;
  double _lastIPD = 0.0;
  int _blinkCount = 0;

  // ── Diagnostic gate ──────────────────────────────────────────────────────────
  // Diagnostic screen is temporarily skipped for the prototype.
  // Set to true so the gate is bypassed and the camera/session starts directly.
  bool _diagnosticsPassed = true;

  @override
  void initState() {
    super.initState();
    _regions = _buildRegions();
    // Do NOT call _initCamera() here. _bootstrapSession() manages the full
    // camera lifecycle: it disposes the camera before opening DiagnosticScreen
    // and reinitialises it afterward. Calling _initCamera() here as well would
    // race with DiagnosticScreen's own camera initialisation, causing
    // "camera already in use" errors on most Android devices.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapSession());
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('⚠️ _initCamera: no cameras available');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // Explicit YUV for NV21
      );
      await _cameraController!.initialize();
      if (!mounted) return;

      // Start camera stream for eye tracking
      _startCameraStream();

      setState(() {});
    } catch (e) {
      debugPrint('❌ _initCamera error: $e');
      if (mounted) setState(() {});
    }
  }

  void _startCameraStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _cameraController!.startImageStream((CameraImage image) async {
      _frameSkipCounter++;
      if (_frameSkipCounter % _frameSkipInterval != 0) {
        // Skip this frame to reduce inference load while keeping latest image.
        _latestCameraImage = image;
        return;
      }

      // Capture image dimensions before the async gap
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final rotation = _getImageRotation();

      // Process with MediaPipe and ML Kit in parallel (fast, on-device)
      final futures = await Future.wait([
        _mediapipe.processImage(image, rotation),
        _mlkit.processImage(image, rotation),
      ]);

      final newMp = futures[0] as MediaPipeIrisData?;
      final newMl = futures[1] as MLKitFaceData?;

      if (mounted) {
        final now = DateTime.now();
        _cameraImageSize = imageSize;
        _latestCameraImage = image;

        // Only update to non-null, or clear after hold-off period expires.
        if (newMp != null) {
          _currentMediaPipeData = newMp;
          _lastDetectionTime = now;
        } else if (_lastDetectionTime != null &&
            now.difference(_lastDetectionTime!) > _detectionHoldDuration) {
          _currentMediaPipeData = null;
        }

        if (newMl != null) {
          _currentMLKitData = newMl;
        }

        if (newMp != null) {
          _overlayMediaPipeData = _mapMediaPipeForOverlay(newMp, imageSize);
        }
        if (newMl != null) {
          _overlayMLKitData = _mapMlkitForOverlay(newMl, imageSize);
        }

        if (_phase == ExperimentPhase.guidelines) {
          if (_currentMediaPipeData != null) {
            _consecutiveDetectionFrames++;
            if (_consecutiveDetectionFrames >= _autoAlignFrameThreshold &&
                !_headAligned) {
              _headAligned = true;
              _alignmentManuallySet = false;
              _tts.speak('Face detected. You may start collection.');
            }
          } else {
            _consecutiveDetectionFrames = 0;
          }
        }

        setState(() {});
      }
    });
  }

  InputImageRotation _getImageRotation() {
    // Use the camera sensor's orientation to produce correctly-oriented
    // InputImage metadata so that MediaPipe/ML Kit landmarks are accurate.
    if (_cameraController == null) return InputImageRotation.rotation0deg;
    final sensorOrientation = _cameraController!.description.sensorOrientation;
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _bootstrapSession() async {
    // ── Step 1: Diagnostics gate ───────────────────────────────────────────────
    // Diagnostic screen is temporarily skipped (_diagnosticsPassed starts true).
    // The camera is initialised directly here so eye data collection still works.
    if (!_diagnosticsPassed) {
      // Stop camera stream before opening diagnostic screen
      // (only one camera can be open at a time on most devices)
      try {
        await _cameraController?.stopImageStream();
      } catch (_) {}
      try {
        await _cameraController?.dispose();
      } catch (_) {}
      _cameraController = null;

      if (!mounted) return;

      final passed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => DiagnosticScreen(
            onPassed: () => Navigator.of(context).pop(true),
          ),
        ),
      );

      // Give the OS a moment to fully release the camera from DiagnosticScreen
      // before we try to re-open it here.
      await Future.delayed(_cameraReleaseDelay);
      if (mounted) await _initCamera();

      if (!mounted) return;
      if (passed != true) {
        // User closed diagnostics without passing – stay on guidelines phase
        setState(() {});
        return;
      }
      _diagnosticsPassed = true;
    } else {
      // Diagnostic screen bypassed – initialise camera directly.
      await _initCamera();
      if (!mounted) return;
    }

    // ── Step 2: Start session & speak guidelines ──────────────────────────────
    if (!mounted) return;
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
    // Keep camera visible so stream continues providing eye tracking data
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

    // Start countdown
    _remainingSeconds = 2;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });

    // 400ms onset delay for gaze to settle on target, then collect for 1.6s.
    _timer?.cancel();
    Timer? dwellSampler;
    Timer(const Duration(milliseconds: 400), () {
      dwellSampler = Timer.periodic(const Duration(milliseconds: 200), (_) {
        _recordSample(mode: ExperimentMode.calibration, region: region);
      });
    });

    Timer(const Duration(seconds: 2), () {
      dwellSampler?.cancel();
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

    // Start countdown (2 seconds total: 1.5s visible + 0.5s gap)
    _remainingSeconds = 2;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });

    // Collect samples every 200ms during the 1.5s visible window
    Timer? pulseSampler;
    pulseSampler = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _recordSample(mode: ExperimentMode.pulse, region: region);
    });

    Timer(const Duration(milliseconds: 1500), () {
      pulseSampler?.cancel();
      Timer(const Duration(milliseconds: 500), () {
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
      _tts.speak('Session complete. Thank you for participating.');
      setState(() {});
      // Navigate to session summary after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (_sessionId != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SessionSummaryScreen(
                args: SessionSummaryArgs(
                  sessionId: _sessionId!,
                  profile: widget.args.profile,
                  languageCode: widget.args.languageCode,
                ),
              ),
            ),
          );
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
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

  Future<void> _recordSample(
      {required ExperimentMode mode,
      required _ColorRegion region,
      String? speedLabel}) async {
    final targetNormalized = _alignmentToNormalized(region.alignment);
    final screenSize = MediaQuery.of(context).size;
    final targetPixel = Offset(
      targetNormalized.dx * screenSize.width,
      targetNormalized.dy * screenSize.height,
    );

    // Build MediaPipeData from current raw iris data (pixel coords)
    MediaPipeData? mediapipeData;
    Offset? leftIrisCenterNorm;
    Offset? rightIrisCenterNorm;
    if (_currentMediaPipeData != null) {
      final mp = _currentMediaPipeData!;
      final imgW = mp.imageWidth == 0 ? 1.0 : mp.imageWidth;
      final imgH = mp.imageHeight == 0 ? 1.0 : mp.imageHeight;

      // Convert normalized [0,1] landmarks back to pixel coords
      final leftIrisPixels = mp.leftIrisLandmarks
          .map((p) => Offset(p.dx * imgW, p.dy * imgH))
          .toList();
      final rightIrisPixels = mp.rightIrisLandmarks
          .map((p) => Offset(p.dx * imgW, p.dy * imgH))
          .toList();
      final leftPupilPx = mp.rawLeftIrisCenterPx ??
          Offset(mp.leftPupilCenter.dx * imgW, mp.leftPupilCenter.dy * imgH);
      final rightPupilPx = mp.rawRightIrisCenterPx ??
          Offset(mp.rightPupilCenter.dx * imgW, mp.rightPupilCenter.dy * imgH);

      leftIrisCenterNorm = Offset(
        (leftPupilPx.dx / imgW).clamp(0.0, 1.0),
        (leftPupilPx.dy / imgH).clamp(0.0, 1.0),
      );
      rightIrisCenterNorm = Offset(
        (rightPupilPx.dx / imgW).clamp(0.0, 1.0),
        (rightPupilPx.dy / imgH).clamp(0.0, 1.0),
      );

      mediapipeData = MediaPipeData(
        leftIrisLandmarks: leftIrisPixels,
        rightIrisLandmarks: rightIrisPixels,
        leftPupilCenter: leftPupilPx,
        rightPupilCenter: rightPupilPx,
        leftEyeOpen: mp.leftEyeOpen,
        rightEyeOpen: mp.rightEyeOpen,
        confidence: mp.confidence,
        faceLandmarkCount: 478,
        // CNN research fields – pass through from MediaPipeIrisData
        leftEyeCropBase64: mp.leftEyeCropBase64,
        rightEyeCropBase64: mp.rightEyeCropBase64,
        leftEAR: mp.leftEAR,
        rightEAR: mp.rightEAR,
        leftIrisDepth: mp.leftIrisDepth,
        rightIrisDepth: mp.rightIrisDepth,
        ipdNormalized: mp.ipdNormalized,
        leftEyeInnerCorner: Offset(
            mp.leftEyeInnerCorner.dx * imgW, mp.leftEyeInnerCorner.dy * imgH),
        leftEyeOuterCorner: Offset(
            mp.leftEyeOuterCorner.dx * imgW, mp.leftEyeOuterCorner.dy * imgH),
        rightEyeInnerCorner: Offset(
            mp.rightEyeInnerCorner.dx * imgW, mp.rightEyeInnerCorner.dy * imgH),
        rightEyeOuterCorner: Offset(
            mp.rightEyeOuterCorner.dx * imgW, mp.rightEyeOuterCorner.dy * imgH),
        faceBox: mp.faceBox != null
            ? Rect.fromLTRB(mp.faceBox!.left * imgW, mp.faceBox!.top * imgH,
                mp.faceBox!.right * imgW, mp.faceBox!.bottom * imgH)
            : null,
      );
    }

    // Build MLKitData from current raw ML Kit data
    MLKitData? mlkitData;
    if (_currentMLKitData != null) {
      final ml = _currentMLKitData!;
      mlkitData = MLKitData(
        gazeEstimate: ml.gazeEstimate,
        headYaw: ml.headYaw,
        headPitch: ml.headPitch,
        headRoll: ml.headRoll,
        faceBounds: ml.faceBounds,
        leftEyeOpenProbability: ml.leftEyeOpenProbability,
        rightEyeOpenProbability: ml.rightEyeOpenProbability,
        confidence: ml.confidence,
      );
    }

    // Quality assessment
    double totalConf = 0;
    int sources = 0;
    if (mediapipeData != null) {
      totalConf += mediapipeData.confidence;
      sources++;
    }
    if (mlkitData != null) {
      totalConf += mlkitData.confidence;
      sources++;
    }
    final overallConf = sources > 0 ? totalConf / sources : 0.0;

    // Skip sample if no eye data was detected at all
    if (sources == 0) {
      debugPrint(
          '[Sample] SKIPPED – no eye data available yet for ${region.label}');
      return;
    }

    final blink = mediapipeData != null &&
        (!mediapipeData.leftEyeOpen || !mediapipeData.rightEyeOpen);
    final headMovement = mlkitData != null &&
            (mlkitData.headYaw.abs() > 15 || mlkitData.headPitch.abs() > 15)
        ? 'large'
        : 'minimal';

    final quality = {
      'overallConfidence': overallConf,
      'mediapipeDetected': mediapipeData != null,
      'mlkitDetected': mlkitData != null,
      'azureDetected': false,
      'blink': blink,
      'headMovement': headMovement,
      'sourceCount': sources,
    };

    // Device info
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final deviceInfo = {
      'screenWidthPixels': screenSize.width.toInt(),
      'screenHeightPixels': screenSize.height.toInt(),
      'screenDensity': view.devicePixelRatio,
      'cameraResolutionWidth': _cameraImageSize.width.toInt(),
      'cameraResolutionHeight': _cameraImageSize.height.toInt(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Participant context
    final profile = widget.args.profile;
    final participantContext = {
      'blindnessType': profile.blindnessType,
      'dominantEye': profile.dominantEye,
      'visionAcuity': profile.visionAcuity,
      'wearsGlasses': profile.wearsGlasses,
      'age': profile.age,
    };

    final sampleId = _uuid.v4();

    // Capture eye crops if we have iris coordinates and a camera frame.
    String? leftCropUrl;
    String? rightCropUrl;
    if (_latestCameraImage != null &&
        leftIrisCenterNorm != null &&
        rightIrisCenterNorm != null) {
      try {
        final crops = await EyeCropService().captureAndUpload(
          image: _latestCameraImage!,
          leftIrisCenterNorm: leftIrisCenterNorm,
          rightIrisCenterNorm: rightIrisCenterNorm,
          sessionId: _sessionId ?? 'unknown',
          sampleId: sampleId,
        );
        leftCropUrl = crops['leftCropUrl'];
        rightCropUrl = crops['rightCropUrl'];
      } catch (e) {
        debugPrint('Eye crop capture failed for sample $sampleId: $e');
      }
    }

    final sample = EyeTrackingSample(
      sampleId: sampleId,
      timestamp: DateTime.now(),
      targetPixel: targetPixel,
      targetNormalized: targetNormalized,
      mode: mode.name,
      colorLabel: region.label,
      speedLabel: speedLabel,
      mediapipeData: mediapipeData,
      mlkitData: mlkitData,
      azureData: null,
      deviceInfo: deviceInfo,
      participantContext: participantContext,
      quality: quality,
      leftEyeCropUrl: leftCropUrl,
      rightEyeCropUrl: rightCropUrl,
    );

    debugPrint('[Sample] mode=${mode.name} color=${region.label} '
        'conf=${overallConf.toStringAsFixed(2)} '
        'mediapipe=${mediapipeData != null} '
        'mlkit=${mlkitData != null} '
        'EAR L=${mediapipeData?.leftEAR.toStringAsFixed(3)} R=${mediapipeData?.rightEAR.toStringAsFixed(3)} '
        'IPD=${mediapipeData?.ipdNormalized.toStringAsFixed(3)} '
        'leftPupil=(${mediapipeData?.leftPupilCenter.dx.toStringAsFixed(1)}, '
        '${mediapipeData?.leftPupilCenter.dy.toStringAsFixed(1)})');

    _pendingSamples.add(sample.toFirestore());

    // Update quality bar state
    _totalSamplesCollected++;
    _lastConfidence = overallConf;
    if (mediapipeData != null) {
      _lastLeftEAR = mediapipeData.leftEAR;
      _lastRightEAR = mediapipeData.rightEAR;
      _lastIPD = mediapipeData.ipdNormalized;
    }
    if (blink) _blinkCount++;

    if (_pendingSamples.length >= CollectionConstants.batchSize) {
      _flushSamples();
    }
  }

  Offset _alignmentToNormalized(Alignment alignment) {
    // Map [-1,1] → [0,1], then add 8% inset from edges so targets are
    // never at the absolute screen corners/edges.
    const pad = 0.08;
    final x = ((alignment.x + 1) / 2) * (1 - 2 * pad) + pad;
    final y = ((alignment.y + 1) / 2) * (1 - 2 * pad) + pad;
    return Offset(x, y);
  }

  Future<void> _flushSamples() async {
    if (_sessionId == null || _pendingSamples.isEmpty) return;
    final userId = widget.args.profile.personId;
    await _firestore.addSamples(
      userId: userId,
      sessionId: _sessionId!,
      samples: List<Map<String, dynamic>>.from(_pendingSamples),
      chunkIndex: _chunkIndex,
    );
    _chunkIndex++;
    _pendingSamples.clear();
  }

  /// Converts MediaPipe normalized [0,1] landmarks to mirrored pixel coords
  /// for the front-camera preview (which Flutter renders horizontally flipped).
  MediaPipeData _mapMediaPipeForOverlay(
      MediaPipeIrisData data, Size imageSize) {
    // Front camera preview is mirrored: flip X  →  mirroredX = (1 - normX) * width
    List<Offset> toMirroredPixels(List<Offset> normPts) => normPts
        .map((p) => Offset(
              (1.0 - p.dx) * imageSize.width,
              p.dy * imageSize.height,
            ))
        .toList(growable: false);

    // Use raw pixel coords when available (already in image space but NOT mirrored)
    // so we still mirror them.
    Offset mirrorPupil(Offset? rawPx, Offset normFallback) {
      if (rawPx != null) {
        // raw pixel → mirror X
        return Offset(imageSize.width - rawPx.dx, rawPx.dy);
      }
      return Offset((1.0 - normFallback.dx) * imageSize.width,
          normFallback.dy * imageSize.height);
    }

    return MediaPipeData(
      leftIrisLandmarks: toMirroredPixels(data.leftIrisLandmarks),
      rightIrisLandmarks: toMirroredPixels(data.rightIrisLandmarks),
      leftPupilCenter:
          mirrorPupil(data.rawLeftIrisCenterPx, data.leftPupilCenter),
      rightPupilCenter:
          mirrorPupil(data.rawRightIrisCenterPx, data.rightPupilCenter),
      leftEyeOpen: data.leftEyeOpen,
      rightEyeOpen: data.rightEyeOpen,
      confidence: data.confidence,
    );
  }

  /// Converts MLKit face data to overlay model.
  /// ML Kit eye-landmark positions are raw pixel coords in the camera image.
  /// The front-camera preview is mirrored, so flip X.
  MLKitData _mapMlkitForOverlay(MLKitFaceData data, Size imageSize) {
    Offset? gaze;
    if (data.gazeEstimate != null) {
      final g = data.gazeEstimate!;
      // g is in normalized [0,1] from mlkit_service; convert to mirrored px
      gaze = Offset(
        (1.0 - g.dx) * imageSize.width,
        g.dy * imageSize.height,
      );
    }

    return MLKitData(
      gazeEstimate: gaze,
      headYaw: data.headYaw,
      headPitch: data.headPitch,
      headRoll: data.headRoll,
      faceBounds: data.faceBounds,
      leftEyeOpenProbability: data.leftEyeOpenProbability,
      rightEyeOpenProbability: data.rightEyeOpenProbability,
      confidence: data.confidence,
    );
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
    const borderColor = Colors.tealAccent;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Collection'),
        actions: [
          IconButton(
            icon: Icon(_showEyeTrackingOverlay
                ? Icons.visibility
                : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _showEyeTrackingOverlay = !_showEyeTrackingOverlay;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_phase == ExperimentPhase.guidelines &&
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
                          color: borderColor.withValues(alpha: 0.6),
                          blurRadius: 24,
                          spreadRadius: 8,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          CameraPreview(_cameraController!),
                          if (_showEyeTrackingOverlay &&
                              _overlayMediaPipeData != null)
                            Positioned.fill(
                              child: EyeTrackingOverlay(
                                mediapipeData: _overlayMediaPipeData,
                                mlkitData: _overlayMLKitData,
                                cameraSize: _cameraImageSize != Size.zero
                                    ? _cameraImageSize
                                    : const Size(320, 240),
                                showDebugInfo:
                                    _phase == ExperimentPhase.guidelines,
                              ),
                            ),
                        ],
                      ),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      color: Colors.tealAccent.withValues(alpha: 0.2),
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
                // ── Real-time quality bar ──────────────────────────────────────
                if (_phase != ExperimentPhase.guidelines &&
                    _phase != ExperimentPhase.done) ...[
                  const SizedBox(height: 6),
                  _buildQualityBar(),
                ],
                const SizedBox(height: 12),
                if (_phase == ExperimentPhase.guidelines) ...[
                  // Eye detection status indicator
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _currentMediaPipeData != null
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentMediaPipeData != null
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: _currentMediaPipeData != null
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentMediaPipeData != null
                              ? 'Eyes detected ✓  (green dots on preview)'
                              : 'Eyes not detected — adjust position',
                          style: TextStyle(
                            color: _currentMediaPipeData != null
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  'ID: ${widget.args.profile.personId}  |  ${widget.args.profile.blindnessType}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          // ── Thank-you overlay (shown when experiment finishes) ──────────────
          if (_phase == ExperimentPhase.done)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.92),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Colors.tealAccent, size: 80),
                    const SizedBox(height: 24),
                    Text(
                      'Thank You!',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Session complete.\nYour data has been saved.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Participant ID: ${widget.args.profile.personId}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white38,
                          ),
                    ),
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(
                        color: Colors.tealAccent, strokeWidth: 2),
                    const SizedBox(height: 16),
                    Text(
                      'Returning to home…',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white38,
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQualityBar() {
    final confColor = _lastConfidence >= 0.8
        ? Colors.greenAccent
        : _lastConfidence >= 0.5
            ? Colors.orangeAccent
            : Colors.redAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: confColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: EAR + IPD + Confidence
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'L-EAR: ${_lastLeftEAR.toStringAsFixed(2)}',
                style: TextStyle(
                  color: confColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'R-EAR: ${_lastRightEAR.toStringAsFixed(2)}',
                style: TextStyle(
                  color: confColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'IPD: ${_lastIPD.toStringAsFixed(3)}',
                style: TextStyle(
                  color: confColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'Conf: ${(_lastConfidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: confColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Row 2: Blinks + Samples
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Blinks: $_blinkCount',
                style: TextStyle(
                  color: confColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'Samples: $_totalSamplesCollected',
                style: TextStyle(
                  color: confColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
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
        _colorIndex = Random().nextInt(_regions.length);
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
      ..color = color.withValues(alpha: 0.7)
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
