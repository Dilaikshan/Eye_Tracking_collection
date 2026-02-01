import 'package:flutter/material.dart';
import 'dart:math' as math;

class CoordinateUtils {
  /// Convert Alignment to normalized screen coordinates (0-1)
  static Offset alignmentToNormalized(Alignment alignment) {
    final x = (alignment.x + 1) / 2;
    final y = (alignment.y + 1) / 2;
    return Offset(x, y);
  }

  /// Convert screen pixel coordinates to normalized (0-1)
  static Offset pixelToNormalized(Offset pixel, Size screenSize) {
    return Offset(
      pixel.dx / screenSize.width,
      pixel.dy / screenSize.height,
    );
  }

  /// Convert normalized coordinates to screen pixels
  static Offset normalizedToPixel(Offset normalized, Size screenSize) {
    return Offset(
      normalized.dx * screenSize.width,
      normalized.dy * screenSize.height,
    );
  }

  /// Calculate Euclidean distance between two points
  static double distance(Offset p1, Offset p2) {
    final dx = p1.dx - p2.dx;
    final dy = p1.dy - p2.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
}
