import 'package:flutter/material.dart';
import 'package:eye_tracking_collection/models/eye_tracking_data.dart';

/// Visual overlay showing real-time eye tracking from different sources
class EyeTrackingOverlay extends StatelessWidget {
  const EyeTrackingOverlay({
    super.key,
    this.mediapipeData,
    this.mlkitData,
    this.azureData,
    this.fusedGaze,
    required this.showOverlay,
  });

  final MediaPipeIrisData? mediapipeData;
  final MLKitFaceData? mlkitData;
  final AzureFaceData? azureData;
  final Offset? fusedGaze;
  final bool showOverlay;

  @override
  Widget build(BuildContext context) {
    if (!showOverlay) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: [
          // MediaPipe gaze (green)
          if (mediapipeData != null)
            _buildGazeIndicator(
              _gazeFromIris(mediapipeData!),
              Colors.greenAccent,
              'MP',
            ),
          // ML Kit gaze (blue)
          if (mlkitData?.gazeEstimate != null)
            _buildGazeIndicator(
              mlkitData!.gazeEstimate!,
              Colors.blueAccent,
              'ML',
            ),
          // Azure gaze (red)
          if (azureData != null)
            _buildGazeIndicator(
              _gazeFromPupils(azureData!),
              Colors.redAccent,
              'AZ',
            ),
          // Fused gaze (yellow - most important)
          if (fusedGaze != null)
            _buildGazeIndicator(
              fusedGaze!,
              Colors.yellowAccent,
              'FUSED',
              size: 24,
            ),
          // Confidence display
          _buildConfidenceDisplay(),
        ],
      ),
    );
  }

  Widget _buildGazeIndicator(Offset position, Color color, String label, {double size = 16}) {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceDisplay() {
    double? confidence;
    int sources = 0;
    if (mediapipeData != null) {
      confidence = (confidence ?? 0) + mediapipeData!.confidence;
      sources++;
    }
    if (mlkitData != null) {
      confidence = (confidence ?? 0) + mlkitData!.confidence;
      sources++;
    }
    if (azureData != null) {
      confidence = (confidence ?? 0) + azureData!.confidence;
      sources++;
    }
    if (sources > 0 && confidence != null) {
      confidence /= sources;
    }

    if (confidence == null) return const SizedBox.shrink();

    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: confidence > 0.8
                ? Colors.greenAccent
                : confidence > 0.6
                    ? Colors.yellowAccent
                    : Colors.redAccent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sources: $sources',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Offset _gazeFromIris(MediaPipeIrisData data) {
    return Offset(
      (data.leftIrisCenter.dx + data.rightIrisCenter.dx) / 2,
      (data.leftIrisCenter.dy + data.rightIrisCenter.dy) / 2,
    );
  }

  Offset _gazeFromPupils(AzureFaceData data) {
    return Offset(
      (data.leftPupil.dx + data.rightPupil.dx) / 2,
      (data.leftPupil.dy + data.rightPupil.dy) / 2,
    );
  }
}
