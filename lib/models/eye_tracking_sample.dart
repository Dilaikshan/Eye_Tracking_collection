import 'package:flutter/material.dart';
import 'package:eye_tracking_collection/models/mediapipe_data.dart';
import 'package:eye_tracking_collection/models/mlkit_data.dart';
import 'package:eye_tracking_collection/models/azure_data.dart';

class EyeTrackingSample {
  final String sampleId;
  final DateTime timestamp;
  final Offset targetPixel;
  final Offset targetNormalized;
  final String mode;
  final String colorLabel;
  final String? speedLabel;

  final MediaPipeData? mediapipeData;
  final MLKitData? mlkitData;
  final AzureData? azureData;

  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic> participantContext;
  final Map<String, dynamic> quality;

  const EyeTrackingSample({
    required this.sampleId,
    required this.timestamp,
    required this.targetPixel,
    required this.targetNormalized,
    required this.mode,
    required this.colorLabel,
    this.speedLabel,
    this.mediapipeData,
    this.mlkitData,
    this.azureData,
    required this.deviceInfo,
    required this.participantContext,
    required this.quality,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'sampleId': sampleId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'target': {
        'pixelX': targetPixel.dx,
        'pixelY': targetPixel.dy,
        'normalizedX': targetNormalized.dx,
        'normalizedY': targetNormalized.dy,
      },
      'mode': mode,
      'colorLabel': colorLabel,
      if (speedLabel != null) 'speedLabel': speedLabel,
      if (mediapipeData != null) 'mediapipe': mediapipeData!.toMap(),
      if (mlkitData != null) 'mlkit': mlkitData!.toMap(),
      if (azureData != null) 'azure': azureData!.toMap(),
      'deviceInfo': deviceInfo,
      'participantContext': participantContext,
      'quality': quality,
    };
  }
}
