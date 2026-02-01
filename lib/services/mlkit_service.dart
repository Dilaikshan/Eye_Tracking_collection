import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:eye_tracking_collection/models/eye_tracking_data.dart';

class MLKitService {
  FaceDetector? _detector;
  bool _isProcessing = false;

  MLKitService() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  Future<MLKitFaceData?> processImage(CameraImage image, InputImageRotation rotation) async {
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
      final headYaw = face.headEulerAngleY ?? 0.0;
      final headPitch = face.headEulerAngleX ?? 0.0;
      final headRoll = face.headEulerAngleZ ?? 0.0;

      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];

      Offset? gazeEstimate;
      if (leftEye != null && rightEye != null) {
        final eyeCenter = Offset(
          (leftEye.position.x + rightEye.position.x) / 2,
          (leftEye.position.y + rightEye.position.y) / 2,
        );
        gazeEstimate = _estimateGazeFromHeadPose(eyeCenter, headYaw, headPitch);
      }

      _isProcessing = false;

      return MLKitFaceData(
        gazeEstimate: gazeEstimate,
        headYaw: headYaw,
        headPitch: headPitch,
        headRoll: headRoll,
        faceBounds: face.boundingBox,
        leftEyeOpenProbability: face.leftEyeOpenProbability ?? 1.0,
        rightEyeOpenProbability: face.rightEyeOpenProbability ?? 1.0,
        confidence: face.trackingId != null ? 0.9 : 0.5,
      );
    } catch (e) {
      _isProcessing = false;
      return null;
    }
  }

  Offset _estimateGazeFromHeadPose(Offset eyeCenter, double yaw, double pitch) {
    final xOffset = yaw * 0.05;
    final yOffset = pitch * 0.05;
    return Offset(eyeCenter.dx + xOffset, eyeCenter.dy + yOffset);
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
