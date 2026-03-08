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
  /// Normalized [0,1] iris center coordinates (for data recording)
  final Offset leftIrisCenter;
  final Offset rightIrisCenter;
  final Offset leftPupilCenter;
  final Offset rightPupilCenter;
  final List<Offset> leftIrisLandmarks; // 5 normalized points per iris
  final List<Offset> rightIrisLandmarks;
  final double confidence;
  final bool leftEyeOpen;
  final bool rightEyeOpen;

  /// Raw pixel coordinates in camera image space (for camera preview overlay)
  final Offset? rawLeftIrisCenterPx;
  final Offset? rawRightIrisCenterPx;
  final double imageWidth;
  final double imageHeight;

  // ── CNN Research Fields ────────────────────────────────────────────────────

  /// 64x64 grayscale JPEG of each eye, base64-encoded (null if extraction failed)
  final String? leftEyeCropBase64;
  final String? rightEyeCropBase64;

  /// Eye Aspect Ratio (float) – use EAR > 0.2 to determine open/closed
  final double leftEAR;
  final double rightEAR;

  /// Iris Z-depth from FaceMesh (raw value from MediaPipe)
  final double leftIrisDepth;
  final double rightIrisDepth;

  /// Interpupillary distance normalized by image width
  final double ipdNormalized;

  /// Eye corner landmarks, normalized [0,1]
  final Offset leftEyeInnerCorner;
  final Offset leftEyeOuterCorner;
  final Offset rightEyeInnerCorner;
  final Offset rightEyeOuterCorner;

  /// Full face bounding box, normalized [0,1]
  final Rect? faceBox;

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
    this.rawLeftIrisCenterPx,
    this.rawRightIrisCenterPx,
    this.imageWidth = 0,
    this.imageHeight = 0,
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
      'leftIrisCenter': {'x': leftIrisCenter.dx, 'y': leftIrisCenter.dy},
      'rightIrisCenter': {'x': rightIrisCenter.dx, 'y': rightIrisCenter.dy},
      'leftPupilCenter': {'x': leftPupilCenter.dx, 'y': leftPupilCenter.dy},
      'rightPupilCenter': {'x': rightPupilCenter.dx, 'y': rightPupilCenter.dy},
      'confidence': confidence,
      'leftEyeOpen': leftEyeOpen,
      'rightEyeOpen': rightEyeOpen,
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
