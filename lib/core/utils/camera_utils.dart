import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CameraUtils {
  static InputImage? convertCameraImage(
      CameraImage image, CameraDescription camera) {
    try {
      final rotation = _rotationFromCamera(camera);
      return _convertToNV21(image, rotation);
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  /// Converts a CameraImage (YUV_420_888 or already NV21) to an NV21 InputImage.
  /// ML Kit on Android only accepts NV21 — multi-plane YUV must be manually
  /// interleaved into a single VU plane.
  static InputImage _convertToNV21(
      CameraImage image, InputImageRotation rotation) {
    final int width  = image.width;
    final int height = image.height;

    // If device already delivers a single NV21 plane, use it directly.
    if (image.planes.length == 1) {
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: width,
        ),
      );
    }

    // YUV_420_888 → NV21
    final Uint8List yBytes  = image.planes[0].bytes;
    final Uint8List uBytes  = image.planes[1].bytes;
    final Uint8List vBytes  = image.planes[2].bytes;

    final int yRowStride  = image.planes[0].bytesPerRow;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final Uint8List nv21 = Uint8List(width * height * 3 ~/ 2);
    int idx = 0;

    // Copy Y plane (strip row-stride padding)
    for (int row = 0; row < height; row++) {
      final int yOff = row * yRowStride;
      for (int col = 0; col < width; col++) {
        nv21[idx++] = yBytes[yOff + col];
      }
    }

    // Interleave V then U (NV21 order)
    final int uvHeight = height ~/ 2;
    final int uvWidth  = width  ~/ 2;
    for (int row = 0; row < uvHeight; row++) {
      for (int col = 0; col < uvWidth; col++) {
        final int uvOff = row * uvRowStride + col * uvPixelStride;
        nv21[idx++] = vBytes[uvOff]; // V first
        nv21[idx++] = uBytes[uvOff]; // then U
      }
    }

    return InputImage.fromBytes(
      bytes: nv21,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: width,
      ),
    );
  }

  static InputImageRotation _rotationFromCamera(CameraDescription camera) {
    if (camera.lensDirection == CameraLensDirection.front) {
      return InputImageRotation.rotation270deg;
    }
    return InputImageRotation.rotation0deg;
  }
}
