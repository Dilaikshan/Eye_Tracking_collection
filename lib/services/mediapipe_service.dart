import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:eye_tracking_collection/models/eye_tracking_data.dart';

class MediaPipeService {
  FaceMeshDetector? _detector;
  bool _isProcessing = false;

  MediaPipeService() {
    _detector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);
  }

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

      if (meshPoints.length < 478) {
        _isProcessing = false;
        return null;
      }

      final imgW = inputImage.metadata?.size.width.toDouble() ?? 0;
      final imgH = inputImage.metadata?.size.height.toDouble() ?? 0;

      final leftIrisPixels = _extractIrisPixels(meshPoints, isLeft: true);
      final rightIrisPixels = _extractIrisPixels(meshPoints, isLeft: false);

      final leftIrisCenterPx = _calculateCenter(leftIrisPixels);
      final rightIrisCenterPx = _calculateCenter(rightIrisPixels);

      // Normalize to [0,1] range using metadata sizes
      final leftIrisNorm = Offset(
        imgW == 0 ? 0 : leftIrisCenterPx.dx / imgW,
        imgH == 0 ? 0 : leftIrisCenterPx.dy / imgH,
      );
      final rightIrisNorm = Offset(
        imgW == 0 ? 0 : rightIrisCenterPx.dx / imgW,
        imgH == 0 ? 0 : rightIrisCenterPx.dy / imgH,
      );

      final leftIrisNormPoints = leftIrisPixels
          .map((p) => Offset(
                imgW == 0 ? 0 : p.dx / imgW,
                imgH == 0 ? 0 : p.dy / imgH,
              ))
          .toList();
      final rightIrisNormPoints = rightIrisPixels
          .map((p) => Offset(
                imgW == 0 ? 0 : p.dx / imgW,
                imgH == 0 ? 0 : p.dy / imgH,
              ))
          .toList();

      final leftEyeOpen = _isEyeOpen(meshPoints, isLeft: true);
      final rightEyeOpen = _isEyeOpen(meshPoints, isLeft: false);

      _isProcessing = false;

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
      );
    } catch (e) {
      _isProcessing = false;
      return null;
    }
  }

  /// Process camera image and extract iris/pupil data.
  /// Returns normalized [0,1] coordinates relative to image size.
  /// Also stores raw pixel coordinates in [rawLeftIrisCenter] / [rawRightIrisCenter]
  /// for camera-preview overlay rendering.
  Future<MediaPipeIrisData?> processImage(
      CameraImage image, InputImageRotation rotation) async {
    if (_isProcessing || _detector == null) return null;
    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image, rotation);
      final faces = await _detector!.processImage(inputImage);

      if (faces.isEmpty) {
        _isProcessing = false;
        return null;
      }

      final face = faces.first;

      // Get all mesh points from the face
      final meshPoints = face.points;

      if (meshPoints.length < 478) {
        _isProcessing = false;
        return null;
      }

      // Image dimensions for normalization
      final imgW = image.width.toDouble();
      final imgH = image.height.toDouble();

      // Extract iris landmarks (MediaPipe indices)
      // Left iris: indices 468-472
      // Right iris: indices 473-477
      final leftIrisPixels = _extractIrisPixels(meshPoints, isLeft: true);
      final rightIrisPixels = _extractIrisPixels(meshPoints, isLeft: false);

      final leftIrisCenterPx = _calculateCenter(leftIrisPixels);
      final rightIrisCenterPx = _calculateCenter(rightIrisPixels);

      // Normalize to [0,1] range
      final leftIrisNorm =
          Offset(leftIrisCenterPx.dx / imgW, leftIrisCenterPx.dy / imgH);
      final rightIrisNorm =
          Offset(rightIrisCenterPx.dx / imgW, rightIrisCenterPx.dy / imgH);

      final leftIrisNormPoints =
          leftIrisPixels.map((p) => Offset(p.dx / imgW, p.dy / imgH)).toList();
      final rightIrisNormPoints =
          rightIrisPixels.map((p) => Offset(p.dx / imgW, p.dy / imgH)).toList();

      // Detect eye open/closed
      final leftEyeOpen = _isEyeOpen(meshPoints, isLeft: true);
      final rightEyeOpen = _isEyeOpen(meshPoints, isLeft: false);

      _isProcessing = false;

      return MediaPipeIrisData(
        // Normalized [0,1] coordinates for data recording
        leftIrisCenter: leftIrisNorm,
        rightIrisCenter: rightIrisNorm,
        leftPupilCenter: leftIrisNorm,
        rightPupilCenter: rightIrisNorm,
        leftIrisLandmarks: leftIrisNormPoints,
        rightIrisLandmarks: rightIrisNormPoints,
        // Raw pixel coordinates for camera-preview overlay
        rawLeftIrisCenterPx: leftIrisCenterPx,
        rawRightIrisCenterPx: rightIrisCenterPx,
        imageWidth: imgW,
        imageHeight: imgH,
        confidence: 0.9,
        leftEyeOpen: leftEyeOpen,
        rightEyeOpen: rightEyeOpen,
      );
    } catch (e) {
      _isProcessing = false;
      return null;
    }
  }

  List<Offset> _extractIrisPixels(List<FaceMeshPoint> meshPoints,
      {required bool isLeft}) {
    // MediaPipe face mesh iris indices:
    // Left iris: 468, 469, 470, 471, 472
    // Right iris: 473, 474, 475, 476, 477

    final startIndex = isLeft ? 468 : 473;
    final irisPoints = <Offset>[];

    for (int i = 0; i < 5; i++) {
      if (startIndex + i < meshPoints.length) {
        final pt = meshPoints[startIndex + i];
        irisPoints.add(Offset(pt.x.toDouble(), pt.y.toDouble()));
      }
    }

    return irisPoints;
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

  bool _isEyeOpen(List<FaceMeshPoint> meshPoints, {required bool isLeft}) {
    // Use eye aspect ratio (EAR) to detect blinks
    // Left eye vertical landmarks: 159 (upper), 145 (lower)
    // Right eye vertical landmarks: 386 (upper), 374 (lower)
    try {
      if (isLeft) {
        final upper = meshPoints[159];
        final lower = meshPoints[145];
        final distance = (upper.y - lower.y).abs();
        return distance > 3;
      } else {
        final upper = meshPoints[386];
        final lower = meshPoints[374];
        final distance = (upper.y - lower.y).abs();
        return distance > 3;
      }
    } catch (e) {
      return true;
    }
  }

  InputImage _convertCameraImage(
      CameraImage image, InputImageRotation rotation) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void dispose() {
    _detector?.close();
    _detector = null;
  }
}
