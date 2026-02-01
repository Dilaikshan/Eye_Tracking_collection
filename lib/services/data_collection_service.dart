import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:eye_tracking_collection/models/eye_tracking_sample.dart';
import 'package:eye_tracking_collection/models/user_profile.dart';
import 'package:eye_tracking_collection/services/mediapipe_service.dart';
import 'package:eye_tracking_collection/services/mlkit_face_service.dart';
import 'package:eye_tracking_collection/services/azure_face_service.dart';
import 'package:eye_tracking_collection/core/constants/collection_constants.dart';

class DataCollectionService {
  final MediaPipeService _mediapipe = MediaPipeService();
  final MLKitFaceService _mlkit = MLKitFaceService();
  final AzureFaceService _azure = AzureFaceService();

  int _frameCount = 0;
  DateTime _lastAzureCall = DateTime.now();
  final Uuid _uuid = const Uuid();

  // Configuration
  static const bool useAzure = true; // Toggle for testing
  UserProfile? _currentProfile;

  void setProfile(UserProfile profile) {
    _currentProfile = profile;
  }

  Future<EyeTrackingSample?> collectSample({
    required InputImage inputImage,
    required Offset target,
    required String mode,
    required String colorLabel,
    String? speedLabel,
  }) async {
    _frameCount++;

    try {
      // 1. ALWAYS collect MediaPipe (primary) - REQUIRED
      final mediapipe = await _mediapipe.processImage(inputImage);

      // 2. ALWAYS collect ML Kit (supplementary) - REQUIRED
      final mlkit = await _mlkit.processImage(inputImage);

      // Check if primary services succeeded
      if (mediapipe == null || mlkit == null) {
        debugPrint('⚠️ Primary service failed - skipping sample');
        return null;
      }

      // 3. OCCASIONALLY collect Azure (validation only) - OPTIONAL
      dynamic azure;
      final timeSinceAzure = DateTime.now().difference(_lastAzureCall);

      if (useAzure &&
          timeSinceAzure.inSeconds >=
              CollectionConstants.azureSampleIntervalSec) {
        try {
          azure = await _azure.processImage(inputImage);
          if (azure != null) {
            _lastAzureCall = DateTime.now();
            debugPrint('✓ Azure validation sample collected');
          }
        } catch (e) {
          debugPrint('⚠️ Azure skipped: $e');
        }
      }

      // 4. Quality assessment
      final quality = _assessQuality(mediapipe, mlkit, azure);

      // 5. Skip low quality samples
      if (quality['overallConfidence'] < CollectionConstants.minConfidence) {
        debugPrint(
            '⚠️ Low quality sample (${quality['overallConfidence']}) - skipping');
        return null;
      }

      // 6. Create sample
      final sample = EyeTrackingSample(
        sampleId: _uuid.v4(),
        timestamp: DateTime.now(),
        target: target,
        mode: mode,
        colorLabel: colorLabel,
        speedLabel: speedLabel,
        mediapipeData: null, // MediaPipe data adapter needed
        mlkitData: mlkit,
        azureData: null, // Azure data adapter needed
        deviceInfo: _getDeviceInfo(inputImage),
        participantContext: _getParticipantContext(),
        quality: quality,
      );

      debugPrint(
          '✓ Sample collected: $mode - $colorLabel (conf: ${quality['overallConfidence']})');
      return sample;
    } catch (e) {
      debugPrint('❌ Error collecting sample: $e');
      return null;
    }
  }

  Map<String, dynamic> _assessQuality(
    dynamic mediapipeData,
    dynamic mlkitData,
    dynamic azureData,
  ) {
    double totalConfidence = 0;
    int sourceCount = 0;

    // MediaPipe confidence
    if (mediapipeData != null && mediapipeData.confidence != null) {
      totalConfidence += mediapipeData.confidence;
      sourceCount++;
    }

    // ML Kit confidence
    if (mlkitData != null && mlkitData.confidence != null) {
      totalConfidence += mlkitData.confidence;
      sourceCount++;
    }

    // Azure confidence (if available)
    if (azureData != null && azureData.confidence != null) {
      totalConfidence += azureData.confidence;
      sourceCount++;
    }

    final overallConfidence =
        sourceCount > 0 ? totalConfidence / sourceCount : 0.0;

    // Detect blinks
    final blink = mediapipeData != null &&
        mediapipeData.leftEyeOpen != null &&
        mediapipeData.rightEyeOpen != null &&
        (!mediapipeData.leftEyeOpen || !mediapipeData.rightEyeOpen);

    // Detect head movement (simplified)
    final headMovement = mlkitData != null &&
            (mlkitData.headYaw.abs() > 15 || mlkitData.headPitch.abs() > 15)
        ? 'large'
        : 'minimal';

    return {
      'overallConfidence': overallConfidence,
      'mediapipeDetected': mediapipeData != null,
      'mlkitDetected': mlkitData != null,
      'azureDetected': azureData != null,
      'blink': blink,
      'headMovement': headMovement,
      'sourceCount': sourceCount,
    };
  }

  Map<String, dynamic> _getDeviceInfo(InputImage inputImage) {
    final metadata = inputImage.metadata;

    return {
      'model': Platform.isAndroid ? 'Android' : 'iOS',
      'screenWidth': metadata?.size.width.toInt() ?? 0,
      'screenHeight': metadata?.size.height.toInt() ?? 0,
      'cameraResolution':
          '${metadata?.size.width.toInt()}x${metadata?.size.height.toInt()}',
      'orientation': metadata?.rotation.name ?? 'unknown',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _getParticipantContext() {
    if (_currentProfile == null) {
      return {
        'blindnessType': 'unknown',
        'dominantEye': 'both',
        'visionAcuity': 5,
        'wearsGlasses': false,
      };
    }

    return {
      'blindnessType': _currentProfile!.blindnessType,
      'dominantEye': _currentProfile!.dominantEye,
      'visionAcuity': _currentProfile!.visionAcuity,
      'wearsGlasses': _currentProfile!.wearsGlasses,
      'age': _currentProfile!.age,
    };
  }

  void dispose() {
    _mediapipe.dispose();
    _mlkit.dispose();
  }

  // Statistics
  int get frameCount => _frameCount;
  void resetFrameCount() => _frameCount = 0;
}
