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

  /// Process camera image and extract iris/pupil data
  Future<MediaPipeIrisData?> processImage(CameraImage image, InputImageRotation rotation) async {
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

      // Extract iris landmarks (MediaPipe indices)
      // Left iris: indices 468-472
      // Right iris: indices 473-477
      final leftIrisPoints = _extractIrisPoints(meshPoints, isLeft: true);
      final rightIrisPoints = _extractIrisPoints(meshPoints, isLeft: false);

      final leftIrisCenter = _calculateCenter(leftIrisPoints);
      final rightIrisCenter = _calculateCenter(rightIrisPoints);

      // Calculate pupil centers (approximate as iris center)
      final leftPupil = leftIrisCenter;
      final rightPupil = rightIrisCenter;

      // Detect eye open/closed
      final leftEyeOpen = _isEyeOpen(meshPoints, isLeft: true);
      final rightEyeOpen = _isEyeOpen(meshPoints, isLeft: false);

      _isProcessing = false;

      return MediaPipeIrisData(
        leftIrisCenter: leftIrisCenter,
        rightIrisCenter: rightIrisCenter,
        leftPupilCenter: leftPupil,
        rightPupilCenter: rightPupil,
        leftIrisLandmarks: leftIrisPoints,
        rightIrisLandmarks: rightIrisPoints,
        confidence: 0.9, // MediaPipe doesn't provide confidence, use fixed
        leftEyeOpen: leftEyeOpen,
        rightEyeOpen: rightEyeOpen,
      );
    } catch (e) {
      _isProcessing = false;
      return null;
    }
  }

  List<Offset> _extractIrisPoints(List<FaceMeshPoint> meshPoints, {required bool isLeft}) {
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
    // Simplified: check vertical distance between upper/lower eyelid points

    // Left eye landmarks: 159, 145 (vertical)
    // Right eye landmarks: 386, 374 (vertical)

    try {
      if (isLeft) {
        final upper = meshPoints[159];
        final lower = meshPoints[145];
        final distance = (upper.y - lower.y).abs();
        return distance > 5; // Threshold for eye open
      } else {
        final upper = meshPoints[386];
        final lower = meshPoints[374];
        final distance = (upper.y - lower.y).abs();
        return distance > 5;
      }
    } catch (e) {
      return true; // Default to open if error
    }
  }

  InputImage _convertCameraImage(CameraImage image, InputImageRotation rotation) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

    final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

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
