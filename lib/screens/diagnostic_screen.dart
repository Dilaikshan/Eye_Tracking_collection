import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eye_tracking_collection/core/constants/app_colors.dart';
import 'package:eye_tracking_collection/models/eye_tracking_data.dart';
import 'package:eye_tracking_collection/services/mediapipe_service.dart';
import 'package:eye_tracking_collection/services/mlkit_service.dart';
import 'package:eye_tracking_collection/widgets/eye_tracking_overlay.dart';
import 'package:eye_tracking_collection/models/mediapipe_data.dart';
import 'package:eye_tracking_collection/models/mlkit_data.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart'
    show InputImageRotation;

enum CheckStatus { pending, running, passed, failed, warning }

class DiagnosticItem {
  final String name;
  CheckStatus status;
  String detail;
  Widget? extraWidget;
  DiagnosticItem({
    required this.name,
    this.status = CheckStatus.pending,
    this.detail = 'Not checked yet',
    this.extraWidget,
  });
}

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key, this.onPassed});
  static const String routeName = '/diagnostic';
  final VoidCallback? onPassed;

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  CameraController? _cameraController;
  final MediaPipeService _mediapipe = MediaPipeService();
  final MLKitService _mlkit = MLKitService();

  MediaPipeIrisData? _liveMediaPipe;
  MLKitFaceData? _liveMlKit;
  MediaPipeData? _overlayMp;
  MLKitData? _overlayMl;
  Size _cameraImageSize = const Size(320, 240);
  bool _streamRunning = false;

  // Track whether camera init is complete so checks don't race it
  bool _cameraReady = false;
  String? _cameraInitError;

  late List<DiagnosticItem> _checks;
  bool _isRunning = false;
  Uint8List? _leftCropBytes; // shown in eye crop check tile

  @override
  void initState() {
    super.initState();
    _buildChecks();
    _initCamera();
  }

  void _buildChecks() {
    _checks = [
      DiagnosticItem(name: 'Camera'),
      DiagnosticItem(name: 'MediaPipe Face Detection'),
      DiagnosticItem(name: 'Eye Crop Extraction'),
      DiagnosticItem(name: 'Head Pose (ML Kit)'),
      DiagnosticItem(name: 'Firestore Connection'),
      DiagnosticItem(name: 'Storage'),
      DiagnosticItem(name: 'Lighting'),
      DiagnosticItem(name: 'Face Distance'),
    ];
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraInitError = 'No cameras found on device');
        return;
      }
      // Prefer front camera for eye tracking
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Use low resolution to avoid CameraX surface-binding conflicts
      _cameraController = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // Explicit YUV for NV21
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
      _startLiveStream();
    } catch (e) {
      debugPrint('❌ DiagnosticScreen camera init: $e');
      if (mounted) setState(() => _cameraInitError = e.toString());
    }
  }

  void _startLiveStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _streamRunning) return;
    _streamRunning = true;

    _cameraController!.startImageStream((CameraImage image) async {
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      // Use correct rotation for front camera on Android.
      // sensorOrientation is the physical sensor rotation; for front cameras
      // ML Kit expects the compensated value (not mirrored).
      final rotation = _getInputImageRotation(
          _cameraController!.description.sensorOrientation);

      final futures = await Future.wait([
        _mediapipe.processImage(image, rotation),
        _mlkit.processImage(image, rotation),
      ]);
      final newMp = futures[0] as MediaPipeIrisData?;
      final newMl = futures[1] as MLKitFaceData?;
      if (!mounted) return;
      setState(() {
        _cameraImageSize = imageSize;
        _liveMediaPipe = newMp;
        _liveMlKit = newMl;
        _overlayMp = newMp != null ? _toOverlayMp(newMp, imageSize) : null;
        _overlayMl = newMl != null ? _toOverlayMl(newMl, imageSize) : null;
      });
    });
  }

  /// Maps sensor orientation degrees to InputImageRotation.
  /// For front cameras Android sensor is typically 270°.
  /// ML Kit needs the rotation that was applied to the image bytes.
  InputImageRotation _getInputImageRotation(int sensorOrientation) {
    // For front-facing cameras on Android, CameraX/camera plugin
    // already accounts for the front mirror, so we pass the sensor angle.
    switch (sensorOrientation) {
      case 90:  return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default:  return InputImageRotation.rotation0deg;
    }
  }

  MediaPipeData _toOverlayMp(MediaPipeIrisData data, Size imageSize) {
    List<Offset> flip(List<Offset> pts) => pts
        .map((p) => Offset(
            (1.0 - p.dx) * imageSize.width, p.dy * imageSize.height))
        .toList();
    Offset flipPupil(Offset? raw, Offset norm) => raw != null
        ? Offset(imageSize.width - raw.dx, raw.dy)
        : Offset(
            (1.0 - norm.dx) * imageSize.width, norm.dy * imageSize.height);
    return MediaPipeData(
      leftIrisLandmarks:  flip(data.leftIrisLandmarks),
      rightIrisLandmarks: flip(data.rightIrisLandmarks),
      leftPupilCenter:
          flipPupil(data.rawLeftIrisCenterPx, data.leftPupilCenter),
      rightPupilCenter:
          flipPupil(data.rawRightIrisCenterPx, data.rightPupilCenter),
      leftEyeOpen:   data.leftEyeOpen,
      rightEyeOpen:  data.rightEyeOpen,
      confidence:    data.confidence,
      leftEAR:       data.leftEAR,
      rightEAR:      data.rightEAR,
      ipdNormalized: data.ipdNormalized,
    );
  }

  MLKitData _toOverlayMl(MLKitFaceData data, Size imageSize) {
    Offset? gaze;
    if (data.gazeEstimate != null) {
      final g = data.gazeEstimate!;
      gaze = Offset(
          (1.0 - g.dx) * imageSize.width, g.dy * imageSize.height);
    }
    return MLKitData(
      gazeEstimate: gaze,
      headYaw:   data.headYaw,
      headPitch: data.headPitch,
      headRoll:  data.headRoll,
      faceBounds: data.faceBounds,
      leftEyeOpenProbability:  data.leftEyeOpenProbability,
      rightEyeOpenProbability: data.rightEyeOpenProbability,
      confidence: data.confidence,
    );
  }

  // ══ DIAGNOSTIC CHECKS ═════════════════════════════════════════════════════

  Future<void> _runAllChecks() async {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    await _checkCamera();
    await _checkMediaPipe();
    await _checkEyeCrops();
    await _checkHeadPose();
    await _checkFirestore();
    await _checkStorage();
    await _checkLighting();
    await _checkFaceDistance();
    setState(() => _isRunning = false);
  }

  Future<void> _checkCamera() async {
    _setStatus(0, CheckStatus.running, 'Checking camera…');

    // Wait up to 5 seconds for camera to actually initialise
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!_cameraReady && _cameraInitError == null &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (_cameraInitError != null) {
      _setStatus(0, CheckStatus.failed,
          'Camera init error: $_cameraInitError ❌');
      return;
    }
    if (!_cameraReady || _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      _setStatus(0, CheckStatus.failed,
          'Camera not ready after 5 s ❌ — check permissions');
      return;
    }

    // previewSize on Android is (height × width) due to landscape sensor;
    // take the larger dimension as width.
    final ps = _cameraController!.value.previewSize;
    final w = ps != null ? ps.longestSide.toInt() : 0;
    final h = ps != null ? ps.shortestSide.toInt() : 0;
    final ok = w >= 480;
    _setStatus(0, ok ? CheckStatus.passed : CheckStatus.warning,
        'Camera: ${w}x$h ${ok ? "✅" : "⚠️ low resolution"}');
  }

  Future<void> _checkMediaPipe() async {
    _setStatus(1, CheckStatus.running, 'Detecting face – please look at camera…');

    if (!_cameraReady) {
      _setStatus(1, CheckStatus.failed,
          'Camera not ready – fix camera check first ❌');
      return;
    }

    // Ensure live stream is running (may need to start it if just initialised)
    if (!_streamRunning) _startLiveStream();

    // Allow up to 8 seconds for first detection (model loading takes time)
    MediaPipeIrisData? result;
    const pollMs  = 300;
    const maxWait = 8000;
    int waited = 0;
    while (waited < maxWait) {
      result = _liveMediaPipe;
      if (result != null) break;
      await Future.delayed(const Duration(milliseconds: pollMs));
      waited += pollMs;
    }

    if (result == null) {
      _setStatus(1, CheckStatus.failed,
          'No face detected after ${maxWait ~/ 1000} s ❌\n'
          '• Ensure camera permission is granted\n'
          '• Position face in front of camera\n'
          '• Ensure good lighting');
      return;
    }
    _setStatus(1, CheckStatus.passed,
        'Face detected ✅  conf=${result.confidence.toStringAsFixed(2)}  '
        'EAR L=${result.leftEAR.toStringAsFixed(2)} '
        'R=${result.rightEAR.toStringAsFixed(2)}');
  }

  Future<void> _checkEyeCrops() async {
    _setStatus(2, CheckStatus.running, 'Extracting eye crops…');
    await Future.delayed(const Duration(milliseconds: 400));
    final data = _liveMediaPipe;
    if (data == null) {
      _setStatus(2, CheckStatus.warning,
          'No face data – crops captured during recording ⚠️');
      return;
    }
    final lCrop = data.leftEyeCropBase64;
    final rCrop = data.rightEyeCropBase64;
    if (lCrop == null && rCrop == null) {
      _setStatus(2, CheckStatus.warning,
          'Eye crops will be captured during recording ⚠️');
      return;
    }
    Uint8List? lBytes, rBytes;
    try {
      if (lCrop != null) lBytes = base64Decode(lCrop);
      if (rCrop != null) rBytes = base64Decode(rCrop);
    } catch (_) {}
    setState(() {
      _leftCropBytes = lBytes;
    });
    _setStatus(
      2,
      CheckStatus.passed,
      'Eye crops extracted – 64×64 grayscale JPEG ✅',
      extra: _CropPreviewWidget(leftBytes: lBytes, rightBytes: rBytes),
    );
  }

  Future<void> _checkHeadPose() async {
    _setStatus(3, CheckStatus.running, 'Checking head pose…');
    await Future.delayed(const Duration(milliseconds: 300));
    final ml = _liveMlKit;
    if (ml == null) {
      _setStatus(3, CheckStatus.warning,
          'ML Kit face not detected – head pose skipped ⚠️\n'
          'This is non-critical; collection still works');
      return;
    }
    final ok = ml.headYaw.abs() <= 45 && ml.headPitch.abs() <= 45;
    _setStatus(
      3,
      ok ? CheckStatus.passed : CheckStatus.warning,
      'Yaw=${ml.headYaw.toStringAsFixed(1)}°  '
      'Pitch=${ml.headPitch.toStringAsFixed(1)}°  '
      'Roll=${ml.headRoll.toStringAsFixed(1)}°  '
      '${ok ? "✅" : "⚠️ tilt too large"}',
    );
  }

  Future<void> _checkFirestore() async {
    _setStatus(4, CheckStatus.running, 'Testing Firestore read/write…');
    try {
      // Write to _health collection (same as permission screen ping)
      final ref = FirebaseFirestore.instance
          .collection('_health')
          .doc('diag_${DateTime.now().millisecondsSinceEpoch}');
      await ref.set({
        'test': true,
        'ts': FieldValue.serverTimestamp(),
        'source': 'diagnostic_screen',
      });
      final snap = await ref.get();
      if (!snap.exists) throw Exception('Write succeeded but read found nothing');
      await ref.delete();
      _setStatus(4, CheckStatus.passed, 'Firestore: Read/Write OK ✅');
    } catch (e) {
      // Firestore being offline is non-fatal – the app queues data locally
      // and syncs when connectivity is restored.
      _setStatus(4, CheckStatus.warning,
          'Firestore offline ⚠️ – data will sync when online\n$e');
    }
  }

  Future<void> _checkStorage() async {
    _setStatus(5, CheckStatus.running, 'Checking storage…');
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      await FileStat.stat('/storage/emulated/0');
      _setStatus(5, CheckStatus.passed, 'Storage: accessible ✅');
    } catch (_) {
      _setStatus(5, CheckStatus.warning,
          'Storage: non-critical – using app directory ⚠️');
    }
  }

  Future<void> _checkLighting() async {
    _setStatus(6, CheckStatus.running, 'Analysing lighting…');
    await Future.delayed(const Duration(milliseconds: 300));
    final mp = _liveMediaPipe;
    if (mp == null) {
      _setStatus(6, CheckStatus.warning,
          'No face – cannot assess lighting ⚠️');
      return;
    }
    if (mp.confidence >= 0.85) {
      _setStatus(6, CheckStatus.passed, 'Lighting: Good ✅');
    } else if (mp.confidence >= 0.6) {
      _setStatus(6, CheckStatus.warning,
          'Lighting: Marginal – brighter area recommended ⚠️');
    } else {
      _setStatus(6, CheckStatus.failed, 'Lighting: Poor ❌');
    }
  }

  Future<void> _checkFaceDistance() async {
    _setStatus(7, CheckStatus.running, 'Estimating face distance…');
    await Future.delayed(const Duration(milliseconds: 300));
    final mp = _liveMediaPipe;
    if (mp == null) {
      _setStatus(7, CheckStatus.warning,
          'No face data – skipped ⚠️');
      return;
    }
    final ipdPx = mp.ipdNormalized * _cameraImageSize.width;
    CheckStatus cs;
    String msg;
    if (ipdPx < 30) {
      cs = CheckStatus.warning;
      msg = 'Possibly too far – move closer ⚠️ (IPD=${ipdPx.toStringAsFixed(0)}px)';
    } else if (ipdPx > 150) {
      cs = CheckStatus.warning;
      msg = 'Possibly too close – move back ⚠️ (IPD=${ipdPx.toStringAsFixed(0)}px)';
    } else {
      cs = CheckStatus.passed;
      msg = 'Good distance ✅ (IPD=${ipdPx.toStringAsFixed(0)}px)';
    }
    _setStatus(7, cs, msg);
  }

  void _setStatus(int idx, CheckStatus s, String detail, {Widget? extra}) {
    if (!mounted) return;
    setState(() {
      _checks[idx].status = s;
      _checks[idx].detail = detail;
      if (extra != null) _checks[idx].extraWidget = extra;
    });
  }

  // Mandatory: Camera + MediaPipe must pass; Firestore offline is non-fatal
  bool get _mandatoryPassed =>
      _checks[0].status == CheckStatus.passed &&
      (_checks[1].status == CheckStatus.passed ||
          _checks[1].status == CheckStatus.warning) &&
      (_checks[4].status == CheckStatus.passed ||
          _checks[4].status == CheckStatus.warning);

  double get _qualityScore {
    final passed =
        _checks.where((c) => c.status == CheckStatus.passed).length;
    return passed / _checks.length;
  }

  // ══ BUILD ══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pre-Collection System Check'),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.surface,
            padding:
                const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: const Text(
              'Research: Assistive Eye-Tracking for Partially Blind Users  |  SEU/IS/19/ICT/047',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontStyle: FontStyle.italic),
            ),
          ),
          _buildCameraPreview(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _checks.length,
              itemBuilder: (ctx, i) => _buildCheckTile(_checks[i]),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final hasCam = _cameraReady &&
        _cameraController != null &&
        _cameraController!.value.isInitialized;
    return Container(
      height: 220,
      color: Colors.black,
      child: Center(
        child: hasCam
            ? Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                  if (_overlayMp != null)
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: EyeTrackingOverlay(
                        mediapipeData: _overlayMp,
                        mlkitData: _overlayMl,
                        cameraSize: _cameraImageSize,
                        showDebugInfo: true,
                      ),
                    ),
                  Positioned(
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: (_liveMediaPipe != null
                                ? Colors.green
                                : Colors.red)
                            .withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _liveMediaPipe != null
                            ? '✅ Face detected  '
                              'EAR L=${_liveMediaPipe!.leftEAR.toStringAsFixed(2)} '
                              'R=${_liveMediaPipe!.rightEAR.toStringAsFixed(2)}'
                            : '❌ No face – look at camera',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_cameraInitError != null) ...[
                    const Icon(Icons.camera_alt,
                        color: Colors.redAccent, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'Camera error:\n$_cameraInitError',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 11),
                    ),
                  ] else ...[
                    const CircularProgressIndicator(
                        color: Colors.tealAccent),
                    const SizedBox(height: 8),
                    const Text('Initializing camera…',
                        style: TextStyle(color: Colors.white54)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildCheckTile(DiagnosticItem item) {
    final icon  = _statusIcon(item.status);
    final color = _statusColor(item.status);
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(item.name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.detail,
                style: TextStyle(color: color, fontSize: 11)),
            if (item.extraWidget != null) ...[
              const SizedBox(height: 4),
              item.extraWidget!,
            ],
          ],
        ),
        trailing: item.status == CheckStatus.running
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.tealAccent))
            : null,
        isThreeLine: item.extraWidget != null,
      ),
    );
  }

  Widget _buildBottomBar() {
    final score  = (_qualityScore * 100).toStringAsFixed(0);
    final allRan =
        _checks.every((c) => c.status != CheckStatus.pending);
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allRan)
            Text(
              'Expected data quality: $score%',
              style: TextStyle(
                color: _qualityScore >= 0.8
                    ? Colors.greenAccent
                    : _qualityScore >= 0.5
                        ? Colors.orangeAccent
                        : Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isRunning ? null : _runAllChecks,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(_isRunning ? 'Running…' : 'Run Checks'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _mandatoryPassed
                      ? () {
                          if (widget.onPassed != null) {
                            widget.onPassed!();
                          } else {
                            Navigator.of(context).pop(true);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Proceed'),
                ),
              ),
            ],
          ),
          if (allRan && !_mandatoryPassed)
            TextButton(
              onPressed: _isRunning ? null : _runAllChecks,
              child: const Text('Retry Failed Checks',
                  style: TextStyle(color: Colors.orangeAccent)),
            ),
        ],
      ),
    );
  }

  IconData _statusIcon(CheckStatus s) {
    switch (s) {
      case CheckStatus.pending: return Icons.radio_button_unchecked;
      case CheckStatus.running: return Icons.hourglass_empty;
      case CheckStatus.passed:  return Icons.check_circle;
      case CheckStatus.warning: return Icons.warning_amber;
      case CheckStatus.failed:  return Icons.cancel;
    }
  }

  Color _statusColor(CheckStatus s) {
    switch (s) {
      case CheckStatus.pending: return Colors.white38;
      case CheckStatus.running: return Colors.tealAccent;
      case CheckStatus.passed:  return Colors.greenAccent;
      case CheckStatus.warning: return Colors.orangeAccent;
      case CheckStatus.failed:  return Colors.redAccent;
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _mediapipe.dispose();
    _mlkit.dispose();
    super.dispose();
  }
}

class _CropPreviewWidget extends StatelessWidget {
  final Uint8List? leftBytes;
  final Uint8List? rightBytes;
  const _CropPreviewWidget({this.leftBytes, this.rightBytes});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _box('Left Eye', leftBytes),
        const SizedBox(width: 8),
        _box('Right Eye', rightBytes),
      ],
    );
  }

  Widget _box(String label, Uint8List? bytes) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.tealAccent),
            borderRadius: BorderRadius.circular(4),
          ),
          child: bytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.memory(bytes, fit: BoxFit.cover))
              : const Center(
                  child: Icon(Icons.image_not_supported,
                      color: Colors.white38, size: 20)),
        ),
      ],
    );
  }
}


