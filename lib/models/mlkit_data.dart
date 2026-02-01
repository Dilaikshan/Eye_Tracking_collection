import 'package:flutter/material.dart';

class MLKitData {
  final Offset? gazeEstimate;
  final double headYaw;
  final double headPitch;
  final double headRoll;
  final Rect faceBounds;
  final double leftEyeOpenProbability;
  final double rightEyeOpenProbability;
  final double confidence;

  const MLKitData({
    this.gazeEstimate,
    required this.headYaw,
    required this.headPitch,
    required this.headRoll,
    required this.faceBounds,
    required this.leftEyeOpenProbability,
    required this.rightEyeOpenProbability,
    required this.confidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'gazeEstimate': gazeEstimate != null
          ? {'x': gazeEstimate!.dx, 'y': gazeEstimate!.dy}
          : null,
      'headPose': {
        'yaw': headYaw,
        'pitch': headPitch,
        'roll': headRoll,
      },
      'faceBounds': {
        'left': faceBounds.left,
        'top': faceBounds.top,
        'width': faceBounds.width,
        'height': faceBounds.height,
      },
      'leftEyeOpenProb': leftEyeOpenProbability,
      'rightEyeOpenProb': rightEyeOpenProbability,
      'confidence': confidence,
    };
  }
}
