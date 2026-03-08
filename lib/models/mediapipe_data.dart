import 'package:flutter/material.dart';

class MediaPipeData {
  final List<Offset> leftIrisLandmarks; // 5 landmarks (468-472)
  final List<Offset> rightIrisLandmarks; // 5 landmarks (473-477)
  final Offset leftPupilCenter;
  final Offset rightPupilCenter;
  final bool leftEyeOpen;
  final bool rightEyeOpen;
  final double confidence;
  final int faceLandmarkCount;

  // ── CNN Research Fields ────────────────────────────────────────────────────
  final String? leftEyeCropBase64;
  final String? rightEyeCropBase64;
  final double leftEAR;
  final double rightEAR;
  final double leftIrisDepth;
  final double rightIrisDepth;
  final double ipdNormalized;
  final Offset leftEyeInnerCorner;
  final Offset leftEyeOuterCorner;
  final Offset rightEyeInnerCorner;
  final Offset rightEyeOuterCorner;
  final Rect? faceBox;

  const MediaPipeData({
    required this.leftIrisLandmarks,
    required this.rightIrisLandmarks,
    required this.leftPupilCenter,
    required this.rightPupilCenter,
    required this.leftEyeOpen,
    required this.rightEyeOpen,
    required this.confidence,
    this.faceLandmarkCount = 468,
    // CNN fields
    this.leftEyeCropBase64,
    this.rightEyeCropBase64,
    this.leftEAR = 0.0,
    this.rightEAR = 0.0,
    this.leftIrisDepth = 0.0,
    this.rightIrisDepth = 0.0,
    this.ipdNormalized = 0.0,
    this.leftEyeInnerCorner = Offset.zero,
    this.leftEyeOuterCorner = Offset.zero,
    this.rightEyeInnerCorner = Offset.zero,
    this.rightEyeOuterCorner = Offset.zero,
    this.faceBox,
  });

  Map<String, dynamic> toMap() {
    return {
      'detected': true,
      'confidence': confidence,
      'leftIris': leftIrisLandmarks
          .map((p) => {'pixelX': p.dx, 'pixelY': p.dy})
          .toList(),
      'rightIris': rightIrisLandmarks
          .map((p) => {'pixelX': p.dx, 'pixelY': p.dy})
          .toList(),
      'leftPupilCenter': {
        'pixelX': leftPupilCenter.dx,
        'pixelY': leftPupilCenter.dy,
      },
      'rightPupilCenter': {
        'pixelX': rightPupilCenter.dx,
        'pixelY': rightPupilCenter.dy,
      },
      'leftEyeOpen': leftEyeOpen,
      'rightEyeOpen': rightEyeOpen,
      'faceLandmarkCount': faceLandmarkCount,
      // CNN research fields
      if (leftEyeCropBase64 != null) 'leftEyeCrop': leftEyeCropBase64,
      if (rightEyeCropBase64 != null) 'rightEyeCrop': rightEyeCropBase64,
      'leftEAR': leftEAR,
      'rightEAR': rightEAR,
      'leftIrisDepth': leftIrisDepth,
      'rightIrisDepth': rightIrisDepth,
      'ipdNormalized': ipdNormalized,
      'eyeCorners': {
        'leftInner': {'x': leftEyeInnerCorner.dx, 'y': leftEyeInnerCorner.dy},
        'leftOuter': {'x': leftEyeOuterCorner.dx, 'y': leftEyeOuterCorner.dy},
        'rightInner': {
          'x': rightEyeInnerCorner.dx,
          'y': rightEyeInnerCorner.dy,
        },
        'rightOuter': {
          'x': rightEyeOuterCorner.dx,
          'y': rightEyeOuterCorner.dy,
        },
      },
      if (faceBox != null)
        'faceBox': {
          'left': faceBox!.left,
          'top': faceBox!.top,
          'right': faceBox!.right,
          'bottom': faceBox!.bottom,
        },
    };
  }
}
