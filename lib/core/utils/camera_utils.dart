import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CameraUtils {
  static InputImage? convertCameraImage(
      CameraImage image, CameraDescription camera) {
    try {
      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: _rotationFromCamera(camera),
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
      return inputImage;
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  static Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  static InputImageRotation _rotationFromCamera(CameraDescription camera) {
    // For Android front camera
    if (camera.lensDirection == CameraLensDirection.front) {
      return InputImageRotation.rotation270deg;
    }
    return InputImageRotation.rotation0deg;
  }
}
