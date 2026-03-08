import 'dart:math';
import 'package:eye_tracking_collection/models/mediapipe_data.dart';
import 'package:eye_tracking_collection/models/mlkit_data.dart';
import 'package:flutter/material.dart';

/// Renders real-time eye-tracking AR overlay on top of the camera preview.
///
/// [mediapipeData] and [mlkitData] carry coordinates already mapped to
/// camera-image pixel space (same as the camera preview pixel size).
/// [cameraSize] is that pixel resolution; the painter scales everything
/// to widget space automatically.
class EyeTrackingOverlay extends StatelessWidget {
  final MediaPipeData? mediapipeData;
  final MLKitData? mlkitData;
  final Size cameraSize;
  final bool showDebugInfo;

  const EyeTrackingOverlay({
    super.key,
    required this.mediapipeData,
    required this.mlkitData,
    required this.cameraSize,
    this.showDebugInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _EyeTrackingPainter(
          mediapipeData: mediapipeData,
          mlkitData: mlkitData,
          showDebugInfo: showDebugInfo,
          cameraSize: cameraSize,
        ),
      ),
    );
  }
}

class _EyeTrackingPainter extends CustomPainter {
  final MediaPipeData? mediapipeData;
  final MLKitData? mlkitData;
  final bool showDebugInfo;
  final Size cameraSize;

  _EyeTrackingPainter({
    required this.mediapipeData,
    required this.mlkitData,
    required this.showDebugInfo,
    required this.cameraSize,
  });

  // Map a point from camera-image pixel space → widget pixel space
  Offset _scale(Offset p, Size widgetSize) {
    if (cameraSize.width == 0 || cameraSize.height == 0) return Offset.zero;
    return Offset(
      (p.dx / cameraSize.width) * widgetSize.width,
      (p.dy / cameraSize.height) * widgetSize.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final mp = mediapipeData;
    final ml = mlkitData;

    // ── Paints ────────────────────────────────────────────────────────────────
    // Green ring for iris contour
    final irisPaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Solid green fill for small landmark dots
    final landmarkPaint = Paint()
      ..color = Colors.lightGreenAccent
      ..style = PaintingStyle.fill;

    // Red filled dot for pupil centre
    final pupilFillPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    // Red stroke for crosshair
    final crosshairPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Yellow for gaze estimate
    final gazePaint = Paint()
      ..color = Colors.yellowAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final gazeFillPaint = Paint()
      ..color = Colors.yellowAccent.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    if (mp != null) {
      // ── Left iris ──────────────────────────────────────────────────────────
      if (mp.leftIrisLandmarks.isNotEmpty) {
        _drawIris(canvas, mp.leftIrisLandmarks, mp.leftPupilCenter,
            irisPaint, landmarkPaint, pupilFillPaint, crosshairPaint, size);
      }

      // ── Right iris ─────────────────────────────────────────────────────────
      if (mp.rightIrisLandmarks.isNotEmpty) {
        _drawIris(canvas, mp.rightIrisLandmarks, mp.rightPupilCenter,
            irisPaint, landmarkPaint, pupilFillPaint, crosshairPaint, size);
      }
    }

    // ── Gaze estimate (from ML Kit) ─────────────────────────────���──────────
    if (ml?.gazeEstimate != null) {
      _drawGaze(canvas, ml!.gazeEstimate!, gazePaint, gazeFillPaint, size);
    }

    // ── Debug text overlay ─────────────────────────────────────────────────
    if (showDebugInfo) {
      _drawDebugInfo(canvas, size, mp, ml);
    }
  }

  /// Draws one iris: circle through the 5 landmarks, small dots on each
  /// landmark, and a filled pupil-centre dot with crosshair.
  void _drawIris(
    Canvas canvas,
    List<Offset> landmarks,
    Offset pupilCenter,
    Paint irisPaint,
    Paint landmarkPaint,
    Paint pupilFillPaint,
    Paint crosshairPaint,
    Size size,
  ) {
    if (landmarks.isEmpty) return;

    // Scale all landmarks to widget space
    final pts = landmarks.map((p) => _scale(p, size)).toList();

    // Compute iris radius from the bounding box of the 5 points
    double minX = pts[0].dx, maxX = pts[0].dx;
    double minY = pts[0].dy, maxY = pts[0].dy;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final center = _scale(pupilCenter, size);
    final radius = max((maxX - minX), (maxY - minY)) / 2.0;
    final displayRadius = radius.clamp(6.0, 60.0);

    // Draw filled semi-transparent iris disc
    final irisFillPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, displayRadius, irisFillPaint);

    // Draw iris ring (OpenCV-style green circle)
    canvas.drawCircle(center, displayRadius, irisPaint);

    // Draw individual landmark dots around the iris
    for (final pt in pts) {
      canvas.drawCircle(pt, 3.0, landmarkPaint);
    }

    // Draw pupil centre dot
    canvas.drawCircle(center, 5.0, pupilFillPaint);

    // Draw crosshair on pupil
    const arm = 12.0;
    canvas.drawLine(
      Offset(center.dx - arm, center.dy),
      Offset(center.dx + arm, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - arm),
      Offset(center.dx, center.dy + arm),
      crosshairPaint,
    );
  }

  /// Draws the gaze estimate point as a yellow ring with centre dot.
  void _drawGaze(
    Canvas canvas,
    Offset gaze,
    Paint strokePaint,
    Paint fillPaint,
    Size size,
  ) {
    final pt = _scale(gaze, size);
    canvas.drawCircle(pt, 10.0, fillPaint);
    canvas.drawCircle(pt, 10.0, strokePaint);

    // Small centre dot
    final dotPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pt, 3.0, dotPaint);
  }

  /// Draws a status panel in the top-left corner (OpenCV-style text overlay).
  void _drawDebugInfo(
      Canvas canvas, Size size, MediaPipeData? mp, MLKitData? ml) {
    final lines = <String>[
      'MediaPipe: ${mp != null ? "✓ detected" : "✗ not detected"}',
      if (mp != null) ...[
        'Conf: ${mp.confidence.toStringAsFixed(2)}',
        'L-Eye: ${mp.leftEyeOpen ? "open" : "closed"}',
        'R-Eye: ${mp.rightEyeOpen ? "open" : "closed"}',
      ],
      if (ml != null) ...[
        'Yaw: ${ml.headYaw.toStringAsFixed(1)}°  '
            'Pitch: ${ml.headPitch.toStringAsFixed(1)}°',
        'ML conf: ${ml.confidence.toStringAsFixed(2)}',
      ],
    ];

    const lineH = 18.0;
    const fontSize = 11.0;
    const padH = 6.0;
    const padV = 4.0;

    // Background panel
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromLTRBR(
        6,
        6,
        220,
        6 + padV * 2 + lineH * lines.length,
        const Radius.circular(6),
      ),
      bgPaint,
    );

    // Text lines
    double y = 6 + padV;
    for (final line in lines) {
      final tp = TextPainter(
        text: TextSpan(
          text: line,
          style: const TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 210);
      tp.paint(canvas, Offset(6 + padH, y));
      y += lineH;
    }
  }

  @override
  bool shouldRepaint(covariant _EyeTrackingPainter old) =>
      old.mediapipeData != mediapipeData ||
      old.mlkitData != mlkitData ||
      old.cameraSize != cameraSize ||
      old.showDebugInfo != showDebugInfo;
}
