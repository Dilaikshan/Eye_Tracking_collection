import 'package:flutter/material.dart';
import 'package:eye_tracking_collection/models/eye_tracking_data.dart';

class DataFusionService {
  /// Combine data from all three sources with weighted averaging.
  /// Even if all sources return null, a metadata-only sample is created
  /// with low confidence so the session/timing data is preserved.
  EyeTrackingData fuseData({
    required Offset target,
    required String mode,
    required String colorLabel,
    MediaPipeIrisData? mediapipe,
    MLKitFaceData? mlkit,
    AzureFaceData? azure,
    String? speedLabel,
  }) {
    // Calculate fused gaze point using weighted average
    Offset? fusedGaze;
    double totalWeight = 0;
    Offset weightedSum = Offset.zero;

    // MediaPipe has highest weight (most accurate for iris)
    if (mediapipe != null && mediapipe.leftEyeOpen && mediapipe.rightEyeOpen) {
      final gazeFromIris = _gazeFromIrisPosition(
        mediapipe.leftIrisCenter,
        mediapipe.rightIrisCenter,
      );
      weightedSum += gazeFromIris * 0.5; // 50% weight
      totalWeight += 0.5;
    }

    // ML Kit has medium weight (good for head pose)
    if (mlkit != null && mlkit.gazeEstimate != null) {
      weightedSum += mlkit.gazeEstimate! * 0.3; // 30% weight
      totalWeight += 0.3;
    }

    // Azure has lower weight (slower but useful for validation)
    if (azure != null) {
      final azureGaze = _gazeFromPupils(azure.leftPupil, azure.rightPupil);
      weightedSum += azureGaze * 0.2; // 20% weight
      totalWeight += 0.2;
    }

    if (totalWeight > 0) {
      fusedGaze = weightedSum / totalWeight;
    }

    // Fuse pupil positions (prefer MediaPipe)
    Offset? fusedLeftPupil;
    Offset? fusedRightPupil;

    if (mediapipe != null) {
      fusedLeftPupil = mediapipe.leftPupilCenter;
      fusedRightPupil = mediapipe.rightPupilCenter;
    } else if (azure != null) {
      fusedLeftPupil = azure.leftPupil;
      fusedRightPupil = azure.rightPupil;
    }

    // Calculate overall confidence
    // Minimum 0.1 so that metadata-only samples are not filtered out
    double confidence = 0.1;
    int sources = 0;
    if (mediapipe != null) {
      confidence += mediapipe.confidence;
      sources++;
    }
    if (mlkit != null) {
      confidence += mlkit.confidence;
      sources++;
    }
    if (azure != null) {
      confidence += azure.confidence;
      sources++;
    }
    // Average across detected sources only (don't dilute by 3 when only 1 available)
    if (sources > 0) confidence = confidence / sources;

    return EyeTrackingData(
      timestamp: DateTime.now(),
      target: target,
      mediapipeData: mediapipe,
      mlkitData: mlkit,
      azureData: azure,
      fusedGaze: fusedGaze,
      fusedLeftPupil: fusedLeftPupil,
      fusedRightPupil: fusedRightPupil,
      mode: mode,
      colorLabel: colorLabel,
      speedLabel: speedLabel,
      overallConfidence: confidence,
      ambientLight: 0.5, // TODO: Get from light sensor
      orientation: 'portraitUp', // TODO: Get actual orientation
    );
  }

  Offset _gazeFromIrisPosition(Offset leftIris, Offset rightIris) {
    return Offset(
      (leftIris.dx + rightIris.dx) / 2,
      (leftIris.dy + rightIris.dy) / 2,
    );
  }

  Offset _gazeFromPupils(Offset leftPupil, Offset rightPupil) {
    return Offset(
      (leftPupil.dx + rightPupil.dx) / 2,
      (leftPupil.dy + rightPupil.dy) / 2,
    );
  }
}
