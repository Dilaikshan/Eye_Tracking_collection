import 'package:flutter/material.dart';

/// Combined eye tracking data from MediaPipe, ML Kit, and Azure
class EyeTrackingData {
  final DateTime timestamp;
  final Offset target; // Where user should look

  // MediaPipe Iris Data
  final MediaPipeIrisData? mediapipeData;

  // Google ML Kit Data
  final MLKitFaceData? mlkitData;

  // Azure Cognitive Services Data
  final AzureFaceData? azureData;

  // Fused/Combined Data
  final Offset? fusedGaze;
  final Offset? fusedLeftPupil;
  final Offset? fusedRightPupil;

  // Metadata
  final String mode; // 'calibration', 'pulse', 'moving'
  final String colorLabel;
  final String? speedLabel;
  final double overallConfidence;

  // Device context
  final double ambientLight;
  final String orientation;

  EyeTrackingData({
    required this.timestamp,
    required this.target,
    this.mediapipeData,
    this.mlkitData,
    this.azureData,
    this.fusedGaze,
    this.fusedLeftPupil,
    this.fusedRightPupil,
    required this.mode,
    required this.colorLabel,
    this.speedLabel,
    required this.overallConfidence,
    this.ambientLight = 0.5,
    this.orientation = 'portraitUp',
  });

  Map<String, dynamic> toFirestore() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'target': {'x': target.dx, 'y': target.dy},
      'mode': mode,
      'color': colorLabel,
      if (speedLabel != null) 'speedLabel': speedLabel,
      if (mediapipeData != null) 'mediapipe': mediapipeData!.toMap(),
      if (mlkitData != null) 'mlkit': mlkitData!.toMap(),
      if (azureData != null) 'azure': azureData!.toMap(),
      'fused': {
        if (fusedGaze != null) 'gaze': {'x': fusedGaze!.dx, 'y': fusedGaze!.dy},
        if (fusedLeftPupil != null) 'leftPupil': {'x': fusedLeftPupil!.dx, 'y': fusedLeftPupil!.dy},
        if (fusedRightPupil != null) 'rightPupil': {'x': fusedRightPupil!.dx, 'y': fusedRightPupil!.dy},
      },
      'metadata': {
        'overallConfidence': overallConfidence,
        'ambientLight': ambientLight,
        'deviceOrientation': orientation,
      },
    };
  }
}

/// MediaPipe Iris tracking data
class MediaPipeIrisData {
  final Offset leftIrisCenter;
  final Offset rightIrisCenter;
  final Offset leftPupilCenter;
  final Offset rightPupilCenter;
  final List<Offset> leftIrisLandmarks; // 5 points per iris
  final List<Offset> rightIrisLandmarks;
  final double confidence;
  final bool leftEyeOpen;
  final bool rightEyeOpen;

  MediaPipeIrisData({
    required this.leftIrisCenter,
    required this.rightIrisCenter,
    required this.leftPupilCenter,
    required this.rightPupilCenter,
    required this.leftIrisLandmarks,
    required this.rightIrisLandmarks,
    required this.confidence,
    required this.leftEyeOpen,
    required this.rightEyeOpen,
  });

  Map<String, dynamic> toMap() {
    return {
      'leftIrisCenter': {'x': leftIrisCenter.dx, 'y': leftIrisCenter.dy},
      'rightIrisCenter': {'x': rightIrisCenter.dx, 'y': rightIrisCenter.dy},
      'leftPupilCenter': {'x': leftPupilCenter.dx, 'y': leftPupilCenter.dy},
      'rightPupilCenter': {'x': rightPupilCenter.dx, 'y': rightPupilCenter.dy},
      'confidence': confidence,
      'leftEyeOpen': leftEyeOpen,
      'rightEyeOpen': rightEyeOpen,
    };
  }
}

/// Google ML Kit Face Detection data
class MLKitFaceData {
  final Offset? gazeEstimate;
  final double headYaw;
  final double headPitch;
  final double headRoll;
  final Rect faceBounds;
  final double leftEyeOpenProbability;
  final double rightEyeOpenProbability;
  final double confidence;

  MLKitFaceData({
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
      if (gazeEstimate != null) 'gazeEstimate': {'x': gazeEstimate!.dx, 'y': gazeEstimate!.dy},
      'headPose': {
        'yaw': headYaw,
        'pitch': headPitch,
        'roll': headRoll,
      },
      'leftEyeOpenProbability': leftEyeOpenProbability,
      'rightEyeOpenProbability': rightEyeOpenProbability,
      'confidence': confidence,
    };
  }
}

/// Azure Cognitive Services Face API data
class AzureFaceData {
  final Offset leftPupil;
  final Offset rightPupil;
  final Map<String, dynamic> headPose;
  final Map<String, dynamic> eyeGaze;
  final double confidence;
  final int latencyMs; // Track API response time

  AzureFaceData({
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
