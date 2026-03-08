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
      'detected': true,
      'confidence': confidence,
      'latencyMs': latencyMs,
      'leftPupil': {
        'pixelX': leftPupil.dx,
        'pixelY': leftPupil.dy,
      },
      'rightPupil': {
        'pixelX': rightPupil.dx,
        'pixelY': rightPupil.dy,
      },
      'headPose': headPose,
      'eyeGaze': eyeGaze,
    };
  }
}
