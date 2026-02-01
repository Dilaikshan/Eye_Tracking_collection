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
      'leftIris': leftIrisLandmarks.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'rightIris':
          rightIrisLandmarks.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'leftPupil': {'x': leftPupilCenter.dx, 'y': leftPupilCenter.dy},
      'rightPupil': {'x': rightPupilCenter.dx, 'y': rightPupilCenter.dy},
      'leftEyeOpen': leftEyeOpen,
      'rightEyeOpen': rightEyeOpen,
      'confidence': confidence,
      'faceLandmarkCount': faceLandmarkCount,
    };
  }
}
