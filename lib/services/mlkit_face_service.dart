import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:eye_tracking_collection/models/mlkit_data.dart';

class MLKitFaceService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  bool _isProcessing = false;

  Future<MLKitData?> processImage(InputImage inputImage) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      final faces = await _detector.processImage(inputImage);

      if (faces.isEmpty) {
        _isProcessing = false;
        return null;
      }

      final face = faces.first;

      // Get head pose
      final headYaw = face.headEulerAngleY ?? 0.0;
      final headPitch = face.headEulerAngleX ?? 0.0;
      final headRoll = face.headEulerAngleZ ?? 0.0;

      // Get eye landmarks
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];

      // Estimate gaze from eye positions and head pose
      Offset? gazeEstimate;
      if (leftEye != null && rightEye != null) {
        final eyeCenter = Offset(
          (leftEye.position.x + rightEye.position.x) / 2,
          (leftEye.position.y + rightEye.position.y) / 2,
        );
        gazeEstimate = _estimateGazeFromHeadPose(eyeCenter, headYaw, headPitch);
      }

      _isProcessing = false;

      return MLKitData(
        gazeEstimate: gazeEstimate,
        headYaw: headYaw,
        headPitch: headPitch,
        headRoll: headRoll,
        faceBounds: face.boundingBox,
        leftEyeOpenProbability: face.leftEyeOpenProbability ?? 1.0,
        rightEyeOpenProbability: face.rightEyeOpenProbability ?? 1.0,
        confidence: face.trackingId != null ? 0.9 : 0.7,
      );
    } catch (e) {
      debugPrint('ML Kit error: $e');
      _isProcessing = false;
      return null;
    }
  }

  Offset _estimateGazeFromHeadPose(Offset eyeCenter, double yaw, double pitch) {
    // Simple linear approximation
    // Positive yaw = looking right, negative = looking left
    // Positive pitch = looking down, negative = looking up
    final xOffset = yaw * 0.05;
    final yOffset = pitch * 0.05;

    return Offset(
      eyeCenter.dx + xOffset,
      eyeCenter.dy + yOffset,
    );
  }

  void dispose() {
    _detector.close();
  }
}
