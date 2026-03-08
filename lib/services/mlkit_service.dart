import 'dart:typed_data';
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

      final imgW = image.width.toDouble();
      final imgH = image.height.toDouble();

      Offset? gazeEstimate;
      if (leftEye != null && rightEye != null) {
        // Normalized [0,1] eye center
        final eyeCenterNorm = Offset(
          ((leftEye.position.x + rightEye.position.x) / 2) / imgW,
          ((leftEye.position.y + rightEye.position.y) / 2) / imgH,
        );
        gazeEstimate = _estimateGazeFromHeadPose(eyeCenterNorm, headYaw, headPitch);
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

  Offset _estimateGazeFromHeadPose(Offset eyeCenterNorm, double yaw, double pitch) {
    // Normalized space: 1 degree of yaw ≈ 0.003 offset in [0,1] space
    final xOffset = yaw * 0.003;
    final yOffset = pitch * 0.003;
    return Offset(
      (eyeCenterNorm.dx + xOffset).clamp(0.0, 1.0),
      (eyeCenterNorm.dy + yOffset).clamp(0.0, 1.0),
    );
  }

  InputImage _convertCameraImage(CameraImage image, InputImageRotation rotation) {
    final int width  = image.width;
    final int height = image.height;

    // Single-plane: already NV21
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

    final int yRowStride    = image.planes[0].bytesPerRow;
    final int uvRowStride   = image.planes[1].bytesPerRow;
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
    final int uvWidth  = width  ~/ 2;
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
    _detector?.close();
    _detector = null;
  }
}
