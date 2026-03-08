import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:eye_tracking_collection/models/eye_tracking_sample.dart';
import 'package:eye_tracking_collection/models/eye_tracking_data.dart'
    show MediaPipeIrisData;
import 'package:eye_tracking_collection/models/mediapipe_data.dart';
import 'package:eye_tracking_collection/models/mlkit_data.dart';
import 'package:eye_tracking_collection/models/azure_data.dart';
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

  Offset _normalizedToPixel(Offset normalized, Size screenSize) {
    return Offset(
      normalized.dx * screenSize.width,
      normalized.dy * screenSize.height,
    );
  }

  Future<EyeTrackingSample?> collectSample({
    required InputImage inputImage,
    required Offset targetNormalized,
    required Size screenSize,
    required String mode,
    required String colorLabel,
    String? speedLabel,
  }) async {
    _frameCount++;

    try {
      final mediapipeRaw = await _mediapipe.processInputImage(inputImage);
      final mediapipe =
          mediapipeRaw != null ? _mapMediaPipeResult(mediapipeRaw) : null;

      final mlkit = await _mlkit.processImage(inputImage);

      if (mediapipe == null || mlkit == null) {
        debugPrint(
            '⚠️ Primary service failed - MediaPipe: ${mediapipe != null}, MLKit: ${mlkit != null}');
        return null;
      }

      if (mediapipe.confidence < CollectionConstants.minIrisConfidence) {
        debugPrint('⚠️ MediaPipe confidence too low: ${mediapipe.confidence}');
        return null;
      }

      // 3. OCCASIONALLY collect Azure (validation only) - OPTIONAL
      AzureData? azure;
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

      final targetPixel = _normalizedToPixel(targetNormalized, screenSize);

      // 6. Create sample
      final sample = EyeTrackingSample(
        sampleId: _uuid.v4(),
        timestamp: DateTime.now(),
        targetPixel: targetPixel,
        targetNormalized: targetNormalized,
        mode: mode,
        colorLabel: colorLabel,
        speedLabel: speedLabel,
        mediapipeData: mediapipe,
        mlkitData: mlkit,
        azureData: azure,
        deviceInfo: _getDeviceInfo(inputImage, screenSize),
        participantContext: _getParticipantContext(),
        quality: quality,
      );

      debugPrint('✓ Sample collected: $mode - $colorLabel');
      debugPrint(
          '  - Target: (${targetPixel.dx.toStringAsFixed(2)}, ${targetPixel.dy.toStringAsFixed(2)})');
      debugPrint(
          '  - Left Pupil: (${mediapipe.leftPupilCenter.dx.toStringAsFixed(2)}, ${mediapipe.leftPupilCenter.dy.toStringAsFixed(2)})');
      debugPrint(
          '  - Right Pupil: (${mediapipe.rightPupilCenter.dx.toStringAsFixed(2)}, ${mediapipe.rightPupilCenter.dy.toStringAsFixed(2)})');
      debugPrint(
          '  - Confidence: ${quality['overallConfidence'].toStringAsFixed(2)}');
      return sample;
    } catch (e) {
      debugPrint('❌ Error collecting sample: $e');
      return null;
    }
  }

  MediaPipeData _mapMediaPipeResult(MediaPipeIrisData data) {
    final width  = data.imageWidth  == 0 ? 1.0 : data.imageWidth;
    final height = data.imageHeight == 0 ? 1.0 : data.imageHeight;

    List<Offset> _scalePoints(List<Offset> points) => points
        .map((p) => Offset(p.dx * width, p.dy * height))
        .toList(growable: false);

    final leftIris   = _scalePoints(data.leftIrisLandmarks);
    final rightIris  = _scalePoints(data.rightIrisLandmarks);

    final leftPupil  = data.rawLeftIrisCenterPx ??
        Offset(data.leftPupilCenter.dx  * width, data.leftPupilCenter.dy  * height);
    final rightPupil = data.rawRightIrisCenterPx ??
        Offset(data.rightPupilCenter.dx * width, data.rightPupilCenter.dy * height);

    // Scale eye corners from normalized [0,1] → pixel space
    Offset _scaleCorner(Offset norm) =>
        Offset(norm.dx * width, norm.dy * height);

    // Scale face box from normalized [0,1] → pixel space
    final faceBoxPx = data.faceBox != null
        ? Rect.fromLTRB(
            data.faceBox!.left   * width,
            data.faceBox!.top    * height,
            data.faceBox!.right  * width,
            data.faceBox!.bottom * height,
          )
        : null;

    return MediaPipeData(
      leftIrisLandmarks:  leftIris,
      rightIrisLandmarks: rightIris,
      leftPupilCenter:    leftPupil,
      rightPupilCenter:   rightPupil,
      leftEyeOpen:        data.leftEyeOpen,
      rightEyeOpen:       data.rightEyeOpen,
      confidence:         data.confidence,
      faceLandmarkCount:  478,
      // CNN research fields
      leftEyeCropBase64:   data.leftEyeCropBase64,
      rightEyeCropBase64:  data.rightEyeCropBase64,
      leftEAR:             data.leftEAR,
      rightEAR:            data.rightEAR,
      leftIrisDepth:       data.leftIrisDepth,
      rightIrisDepth:      data.rightIrisDepth,
      ipdNormalized:       data.ipdNormalized,
      leftEyeInnerCorner:  _scaleCorner(data.leftEyeInnerCorner),
      leftEyeOuterCorner:  _scaleCorner(data.leftEyeOuterCorner),
      rightEyeInnerCorner: _scaleCorner(data.rightEyeInnerCorner),
      rightEyeOuterCorner: _scaleCorner(data.rightEyeOuterCorner),
      faceBox:             faceBoxPx,
    );
  }

  Map<String, dynamic> _assessQuality(
    MediaPipeData mediapipeData,
    MLKitData mlkitData,
    AzureData? azureData,
  ) {
    double totalConfidence = 0;
    int sourceCount = 0;

    totalConfidence += mediapipeData.confidence;
    sourceCount++;

    totalConfidence += mlkitData.confidence;
    sourceCount++;

    if (azureData != null) {
      totalConfidence += azureData.confidence;
      sourceCount++;
    }

    final overallConfidence =
        sourceCount > 0 ? totalConfidence / sourceCount : 0.0;

    // Detect blinks
    final blink = !mediapipeData.leftEyeOpen || !mediapipeData.rightEyeOpen;

    final headMovement =
        (mlkitData.headYaw.abs() > 15 || mlkitData.headPitch.abs() > 15)
            ? 'large'
            : 'minimal';

    return {
      'overallConfidence': overallConfidence,
      'mediapipeDetected': true,
      'mlkitDetected': true,
      'azureDetected': azureData != null,
      'blink': blink,
      'headMovement': headMovement,
      'sourceCount': sourceCount,
    };
  }

  Map<String, dynamic> _getDeviceInfo(InputImage inputImage, Size screenSize) {
    final metadata = inputImage.metadata;
    final view = WidgetsBinding.instance.platformDispatcher.views.first;

    return {
      'model': Platform.isAndroid ? 'Android' : 'iOS',
      'screenWidthPixels': screenSize.width.toInt(),
      'screenHeightPixels': screenSize.height.toInt(),
      'screenDensity': view.devicePixelRatio,
      'cameraResolutionWidth': metadata?.size.width.toInt() ?? 0,
      'cameraResolutionHeight': metadata?.size.height.toInt() ?? 0,
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
