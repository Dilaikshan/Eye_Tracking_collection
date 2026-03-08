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

  const MediaPipeData({
    required this.leftIrisLandmarks,
    required this.rightIrisLandmarks,
    required this.leftPupilCenter,
    required this.rightPupilCenter,
    required this.leftEyeOpen,
    required this.rightEyeOpen,
    required this.confidence,
    this.faceLandmarkCount = 468,
  });

  Map<String, dynamic> toMap() {
    return {
      'detected': true,
      'confidence': confidence,
      'leftIris': leftIrisLandmarks
          .map((p) => {
                'pixelX': p.dx,
                'pixelY': p.dy,
              })
          .toList(),
      'rightIris': rightIrisLandmarks
          .map((p) => {
                'pixelX': p.dx,
                'pixelY': p.dy,
              })
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
    };
  }
}
