import 'dart:typed_data';
import 'package:camera/camera.dart';
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

  /// Process an already-converted InputImage (e.g. from camera_utils).
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

  /// Process directly from a CameraImage using correct NV21 conversion.
  Future<MLKitData?> processFromCameraImage(
      CameraImage image, InputImageRotation rotation) {
    return processImage(_convertCameraImageToNV21(image, rotation));
  }

  Offset _estimateGazeFromHeadPose(
      Offset eyeCenter, double yaw, double pitch) {
    return Offset(
      eyeCenter.dx + yaw * 0.05,
      eyeCenter.dy + pitch * 0.05,
    );
  }

  /// YUV_420_888 → NV21 conversion (ML Kit Android requirement).
  InputImage _convertCameraImageToNV21(
      CameraImage image, InputImageRotation rotation) {
    final int width = image.width;
    final int height = image.height;

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

    final Uint8List yBytes = image.planes[0].bytes;
    final Uint8List uBytes = image.planes[1].bytes;
    final Uint8List vBytes = image.planes[2].bytes;

    final int yRowStride = image.planes[0].bytesPerRow;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final Uint8List nv21 = Uint8List(width * height * 3 ~/ 2);
    int idx = 0;

    for (int row = 0; row < height; row++) {
      final int yOff = row * yRowStride;
      for (int col = 0; col < width; col++) {
        nv21[idx++] = yBytes[yOff + col];
      }
    }

    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;
    for (int row = 0; row < uvHeight; row++) {
      for (int col = 0; col < uvWidth; col++) {
        final int uvOff = row * uvRowStride + col * uvPixelStride;
        nv21[idx++] = vBytes[uvOff];
        nv21[idx++] = uBytes[uvOff];
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
    _detector.close();
  }
}
