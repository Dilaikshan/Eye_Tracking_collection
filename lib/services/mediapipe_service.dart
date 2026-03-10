import 'dart:convert';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:image/image.dart' as img;
import 'package:eye_tracking_collection/models/eye_tracking_data.dart';

class MediaPipeService {
  FaceMeshDetector? _detector;
  bool _isProcessing = false;
  int _frameCount = 0;

  // ── Landmark index constants ────────────────────────────────────────────────

  // Iris landmarks (MediaPipe 478-point model)
  static const int _leftIrisStart = 468; // 468-472 (5 points)
  static const int _rightIrisStart = 473; // 473-477 (5 points)
  static const int _minFaceMeshPoints = 468;

  // Eye corners
  static const int _leftEyeInner = 133; // right corner of left eye (inner)
  static const int _leftEyeOuter = 33; // left corner of left eye (outer)
  static const int _rightEyeInner = 362; // left corner of right eye (inner)
  static const int _rightEyeOuter = 263; // right corner of right eye (outer)

  // EAR landmarks – left eye: p1=33, p2=160, p3=158, p4=133, p5=153, p6=144
  static const List<int> _leftEarIdx = [33, 160, 158, 133, 153, 144];
  // EAR landmarks – right eye: p1=362, p2=385, p3=387, p4=263, p5=380, p6=373
  static const List<int> _rightEarIdx = [362, 385, 387, 263, 380, 373];

  MediaPipeService() {
    _detector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);
  }

  // ── Public API: InputImage variant ─────────────────────────────────────────

  Future<MediaPipeIrisData?> processInputImage(InputImage inputImage) async {
    if (_isProcessing || _detector == null) return null;
    _isProcessing = true;

    try {
      final faces = await _detector!.processImage(inputImage);
      if (faces.isEmpty) {
        _isProcessing = false;
        return null;
      }

      final face = faces.first;
      final meshPoints = face.points;
      if (meshPoints.length < _minFaceMeshPoints) {
        _isProcessing = false;
        return null;
      }

      final imgW = inputImage.metadata?.size.width.toDouble() ?? 1.0;
      final imgH = inputImage.metadata?.size.height.toDouble() ?? 1.0;

      final result = _extractAllData(
        meshPoints: meshPoints,
        imgW: imgW,
        imgH: imgH,
        rawBytes: null,
        rawBytesPerRow: 0,
      );

      _isProcessing = false;
      return result;
    } catch (e) {
      debugPrint('❌ MediaPipe processInputImage error: $e');
      _isProcessing = false;
      return null;
    }
  }

  // ── Public API: CameraImage variant ─────────────────────────────────────────

  Future<MediaPipeIrisData?> processImage(
      CameraImage image, InputImageRotation rotation) async {
    if (_isProcessing || _detector == null) return null;
    _isProcessing = true;

    // Log format info on first frame only
    if (_frameCount == 0) {
      debugPrint('📷 Camera format: ${image.format.raw} '
          '(${image.format.group.name}) '
          'size: ${image.width}x${image.height} '
          'planes: ${image.planes.length} '
          'plane[0] bytesPerRow: ${image.planes[0].bytesPerRow}');
    }
    _frameCount++;

    try {
      final inputImage = _convertCameraImageToNV21(image, rotation);
      final faces = await _detector!.processImage(inputImage);
      if (faces.isEmpty) {
        _isProcessing = false;
        return null;
      }

      final face = faces.first;
      final meshPoints = face.points;
      if (meshPoints.length < _minFaceMeshPoints) {
        _isProcessing = false;
        return null;
      }

      final imgW = image.width.toDouble();
      final imgH = image.height.toDouble();

      // Pass raw image bytes for eye crop extraction
      final result = _extractAllData(
        meshPoints: meshPoints,
        imgW: imgW,
        imgH: imgH,
        rawBytes: image.planes.first.bytes,
        rawBytesPerRow: image.planes.first.bytesPerRow,
        imageForCrop: image,
      );

      _isProcessing = false;
      return result;
    } catch (e) {
      debugPrint('❌ MediaPipe processImage error: $e');
      _isProcessing = false;
      return null;
    }
  }

  // ── Core extraction logic ────────────────────────────────────────────────────

  MediaPipeIrisData _extractAllData({
    required List<FaceMeshPoint> meshPoints,
    required double imgW,
    required double imgH,
    required Uint8List? rawBytes,
    required int rawBytesPerRow,
    CameraImage? imageForCrop,
  }) {
    // 1. Iris pixel positions
    final leftIrisPixels = _extractIrisPixels(meshPoints, isLeft: true);
    final rightIrisPixels = _extractIrisPixels(meshPoints, isLeft: false);

    final leftIrisCenterPx = _calculateCenter(leftIrisPixels);
    final rightIrisCenterPx = _calculateCenter(rightIrisPixels);

    // Normalize to [0,1]
    final leftIrisNorm =
        Offset(leftIrisCenterPx.dx / imgW, leftIrisCenterPx.dy / imgH);
    final rightIrisNorm =
        Offset(rightIrisCenterPx.dx / imgW, rightIrisCenterPx.dy / imgH);

    final leftIrisNormPoints =
        leftIrisPixels.map((p) => Offset(p.dx / imgW, p.dy / imgH)).toList();
    final rightIrisNormPoints =
        rightIrisPixels.map((p) => Offset(p.dx / imgW, p.dy / imgH)).toList();

    // 2. EAR (float)
    final leftEAR = _computeEAR(meshPoints, _leftEarIdx);
    final rightEAR = _computeEAR(meshPoints, _rightEarIdx);

    // 3. Eye open from EAR
    final leftEyeOpen = leftEAR > 0.2;
    final rightEyeOpen = rightEAR > 0.2;

    // 4. Iris Z-depth
    final leftIrisDepth = meshPoints.length > _leftIrisStart + 4
        ? meshPoints[_leftIrisStart + 4].z.toDouble()
        : 0.0;
    final rightIrisDepth = meshPoints.length > _rightIrisStart + 4
        ? meshPoints[_rightIrisStart + 4].z.toDouble()
        : 0.0;

    // 5. IPD normalized
    final dx = (leftIrisCenterPx.dx - rightIrisCenterPx.dx);
    final dy = (leftIrisCenterPx.dy - rightIrisCenterPx.dy);
    final ipdPx = sqrt(dx * dx + dy * dy);
    final ipdNormalized = imgW > 0 ? ipdPx / imgW : 0.0;

    // 6. Eye corners (normalized)
    final leftInner = _normPoint(meshPoints, _leftEyeInner, imgW, imgH);
    final leftOuter = _normPoint(meshPoints, _leftEyeOuter, imgW, imgH);
    final rightInner = _normPoint(meshPoints, _rightEyeInner, imgW, imgH);
    final rightOuter = _normPoint(meshPoints, _rightEyeOuter, imgW, imgH);

    // 7. Face bounding box (normalized)
    final faceBox = _computeFaceBox(meshPoints, imgW, imgH);

    // 8. Eye crops (64x64 grayscale base64) – best effort
    String? leftCropB64;
    String? rightCropB64;
    if (imageForCrop != null) {
      try {
        leftCropB64 = _extractEyeCrop(imageForCrop, meshPoints, isLeft: true);
        rightCropB64 = _extractEyeCrop(imageForCrop, meshPoints, isLeft: false);
      } catch (e) {
        debugPrint('⚠️ Eye crop extraction failed: $e');
      }
    }

    debugPrint('✅ MediaPipe: L-EAR=${leftEAR.toStringAsFixed(3)} '
        'R-EAR=${rightEAR.toStringAsFixed(3)} '
        'IPD=${ipdNormalized.toStringAsFixed(3)} '
        'crops=${leftCropB64 != null ? "ok" : "null"}');

    return MediaPipeIrisData(
      leftIrisCenter: leftIrisNorm,
      rightIrisCenter: rightIrisNorm,
      leftPupilCenter: leftIrisNorm,
      rightPupilCenter: rightIrisNorm,
      leftIrisLandmarks: leftIrisNormPoints,
      rightIrisLandmarks: rightIrisNormPoints,
      rawLeftIrisCenterPx: leftIrisCenterPx,
      rawRightIrisCenterPx: rightIrisCenterPx,
      imageWidth: imgW,
      imageHeight: imgH,
      confidence: 0.9,
      leftEyeOpen: leftEyeOpen,
      rightEyeOpen: rightEyeOpen,
      leftEyeCropBase64: leftCropB64,
      rightEyeCropBase64: rightCropB64,
      leftEAR: leftEAR,
      rightEAR: rightEAR,
      leftIrisDepth: leftIrisDepth,
      rightIrisDepth: rightIrisDepth,
      ipdNormalized: ipdNormalized,
      leftEyeInnerCorner: leftInner,
      leftEyeOuterCorner: leftOuter,
      rightEyeInnerCorner: rightInner,
      rightEyeOuterCorner: rightOuter,
      faceBox: faceBox,
    );
  }

  // ── EAR calculation ──────────────────────────────────────────────────────────
  // EAR = (|p2-p6| + |p3-p5|) / (2 * |p1-p4|)
  // idx: [p1, p2, p3, p4, p5, p6]
  double _computeEAR(List<FaceMeshPoint> pts, List<int> idx) {
    try {
      final p1 = pts[idx[0]];
      final p2 = pts[idx[1]];
      final p3 = pts[idx[2]];
      final p4 = pts[idx[3]];
      final p5 = pts[idx[4]];
      final p6 = pts[idx[5]];

      final v1 = _dist2(p2, p6);
      final v2 = _dist2(p3, p5);
      final h = _dist2(p1, p4);

      if (h < 1e-9) return 0.0;
      return (v1 + v2) / (2.0 * h);
    } catch (_) {
      return 0.3; // fallback → eye open
    }
  }

  double _dist2(FaceMeshPoint a, FaceMeshPoint b) {
    final dx = (a.x - b.x).toDouble();
    final dy = (a.y - b.y).toDouble();
    return sqrt(dx * dx + dy * dy);
  }

  // ── Face bounding box ────────────────────────────────────────────────────────
  Rect _computeFaceBox(List<FaceMeshPoint> pts, double imgW, double imgH) {
    double minX = double.maxFinite, maxX = -double.maxFinite;
    double minY = double.maxFinite, maxY = -double.maxFinite;
    for (final p in pts) {
      if (p.x < minX) minX = p.x.toDouble();
      if (p.x > maxX) maxX = p.x.toDouble();
      if (p.y < minY) minY = p.y.toDouble();
      if (p.y > maxY) maxY = p.y.toDouble();
    }
    return Rect.fromLTRB(
      imgW > 0 ? minX / imgW : 0,
      imgH > 0 ? minY / imgH : 0,
      imgW > 0 ? maxX / imgW : 1,
      imgH > 0 ? maxY / imgH : 1,
    );
  }

  // ── Normalise a single landmark ──────────────────────────────────────────────
  Offset _normPoint(List<FaceMeshPoint> pts, int idx, double w, double h) {
    if (idx >= pts.length) return Offset.zero;
    return Offset(
      w > 0 ? pts[idx].x.toDouble() / w : 0,
      h > 0 ? pts[idx].y.toDouble() / h : 0,
    );
  }

  // ── 64×64 grayscale eye crop ─────────────────────────────────────────────────
  /// Extracts a 64x64 grayscale eye crop from the raw NV21/YUV camera image.
  /// Uses the eye landmark bounding box + 20% padding on each side.
  /// Returns base64-encoded JPEG string, or null on failure.
  String? _extractEyeCrop(
    CameraImage camImage,
    List<FaceMeshPoint> meshPoints, {
    required bool isLeft,
  }) {
    try {
      // Landmarks that define the eye region
      final eyeLandmarks = isLeft
          ? [33, 133, 159, 145, 160, 144, 158, 153] // left eye
          : [362, 263, 386, 374, 385, 380, 387, 373]; // right eye

      double minX = double.maxFinite, maxX = -double.maxFinite;
      double minY = double.maxFinite, maxY = -double.maxFinite;

      for (final idx in eyeLandmarks) {
        if (idx >= meshPoints.length) continue;
        final p = meshPoints[idx];
        if (p.x < minX) minX = p.x.toDouble();
        if (p.x > maxX) maxX = p.x.toDouble();
        if (p.y < minY) minY = p.y.toDouble();
        if (p.y > maxY) maxY = p.y.toDouble();
      }

      final bboxW = maxX - minX;
      final bboxH = maxY - minY;
      if (bboxW <= 0 || bboxH <= 0) return null;

      // 20% padding
      final padX = bboxW * 0.20;
      final padY = bboxH * 0.20;

      final cropX = (minX - padX).clamp(0.0, camImage.width.toDouble() - 1);
      final cropY = (minY - padY).clamp(0.0, camImage.height.toDouble() - 1);
      final cropW =
          ((bboxW + 2 * padX)).clamp(1.0, camImage.width.toDouble() - cropX);
      final cropH =
          ((bboxH + 2 * padY)).clamp(1.0, camImage.height.toDouble() - cropY);

      // Decode YUV (NV21) to RGB using the `image` package
      final yPlane = camImage.planes[0];
      final imgWidth = camImage.width;
      final imgHeight = camImage.height;

      // Build a grayscale image directly from the Y-plane (luma channel)
      final grayImage =
          img.Image(width: imgWidth, height: imgHeight, numChannels: 1);

      final yBytes = yPlane.bytes;
      final rowStride = yPlane.bytesPerRow;

      for (int row = 0; row < imgHeight; row++) {
        for (int col = 0; col < imgWidth; col++) {
          final yIdx = row * rowStride + col;
          if (yIdx >= yBytes.length) continue;
          final luma = yBytes[yIdx];
          grayImage.setPixel(col, row, img.ColorUint8.rgb(luma, luma, luma));
        }
      }

      // Crop
      final cropped = img.copyCrop(
        grayImage,
        x: cropX.toInt(),
        y: cropY.toInt(),
        width: cropW.toInt(),
        height: cropH.toInt(),
      );

      // Resize to 64×64
      final resized = img.copyResize(cropped,
          width: 64, height: 64, interpolation: img.Interpolation.linear);

      // Encode as JPEG
      final jpegBytes = img.encodeJpg(resized, quality: 85);
      return base64Encode(jpegBytes);
    } catch (e) {
      debugPrint('⚠️ Eye crop failed: $e');
      return null;
    }
  }

  // ── Iris pixel helpers ────────────────────────────────────────────────────────
  List<Offset> _extractIrisPixels(List<FaceMeshPoint> meshPoints,
      {required bool isLeft}) {
    final startIndex = isLeft ? _leftIrisStart : _rightIrisStart;
    final irisPoints = <Offset>[];
    for (int i = 0; i < 5; i++) {
      if (startIndex + i < meshPoints.length) {
        final pt = meshPoints[startIndex + i];
        irisPoints.add(Offset(pt.x.toDouble(), pt.y.toDouble()));
      }
    }

    if (irisPoints.isNotEmpty) return irisPoints;

    return _extractFallbackEyePoints(meshPoints, isLeft: isLeft);
  }

  List<Offset> _extractFallbackEyePoints(List<FaceMeshPoint> meshPoints,
      {required bool isLeft}) {
    final candidates = isLeft
        ? const [33, 133, 159, 145, 158]
        : const [362, 263, 386, 374, 387];

    final points = <Offset>[];
    for (final index in candidates) {
      if (index < meshPoints.length) {
        final pt = meshPoints[index];
        points.add(Offset(pt.x.toDouble(), pt.y.toDouble()));
      }
    }

    if (points.length >= 5) {
      return points.take(5).toList(growable: false);
    }

    if (points.isEmpty) return points;
    final center = _calculateCenter(points);
    return List<Offset>.filled(5, center, growable: false);
  }

  Offset _calculateCenter(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    double sumX = 0, sumY = 0;
    for (final pt in points) {
      sumX += pt.dx;
      sumY += pt.dy;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }

  // ── Camera image conversion (YUV_420_888 → NV21) ────────────────────────────
  /// Converts a CameraImage to an NV21 InputImage that ML Kit accepts on Android.
  /// Handles both single-plane devices (already NV21) and multi-plane YUV_420_888.
  InputImage _convertCameraImageToNV21(
      CameraImage image, InputImageRotation rotation) {
    final int width = image.width;
    final int height = image.height;

    // Single-plane: device already outputs NV21 — use directly
    if (image.planes.length == 1) {
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: width,
        ),
      );
    }

    // Multi-plane YUV_420_888 → NV21
    final Uint8List yBytes = image.planes[0].bytes;
    final Uint8List uBytes = image.planes[1].bytes;
    final Uint8List vBytes = image.planes[2].bytes;

    final int yRowStride = image.planes[0].bytesPerRow;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final Uint8List nv21 = Uint8List(width * height * 3 ~/ 2);
    int idx = 0;

    // Copy Y plane (strip row-stride padding)
    for (int row = 0; row < height; row++) {
      final int yOff = row * yRowStride;
      for (int col = 0; col < width; col++) {
        nv21[idx++] = yBytes[yOff + col];
      }
    }

    // Interleave V then U (NV21 = VU order)
    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;
    for (int row = 0; row < uvHeight; row++) {
      for (int col = 0; col < uvWidth; col++) {
        final int uvOff = row * uvRowStride + col * uvPixelStride;
        nv21[idx++] = vBytes[uvOff]; // V first
        nv21[idx++] = uBytes[uvOff]; // then U
      }
    }

    return InputImage.fromBytes(
      bytes: nv21,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: width,
      ),
    );
  }

  void dispose() {
    _detector?.close();
    _detector = null;
  }
}
