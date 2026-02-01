import 'package:flutter/material.dart';

class AzureData {
  final Offset leftPupil;
  final Offset rightPupil;
  final Map<String, dynamic> headPose;
  final Map<String, dynamic> eyeGaze;
  final double confidence;
  final int latencyMs;

  const AzureData({
    required this.leftPupil,
    required this.rightPupil,
    required this.headPose,
    required this.eyeGaze,
    required this.confidence,
    required this.latencyMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'leftPupil': {'x': leftPupil.dx, 'y': leftPupil.dy},
      'rightPupil': {'x': rightPupil.dx, 'y': rightPupil.dy},
      'headPose': headPose,
      'eyeGaze': eyeGaze,
      'confidence': confidence,
      'latencyMs': latencyMs,
    };
  }
}
