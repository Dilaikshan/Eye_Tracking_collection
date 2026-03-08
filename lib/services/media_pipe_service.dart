import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Size;
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

class MediaPipeService {
  MediaPipeService({this.onResults});

  final void Function(List<FaceMesh> meshes)? onResults;
  FaceMeshDetector? _detector;
  bool _isRunning = false;

  Future<void> start() async {
    if (_isRunning) return;
    _detector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);
    _isRunning = true;
  }

  Future<void> stop() async {
    _isRunning = false;
    await _detector?.close();
    _detector = null;
  }

  Future<void> processCameraImage(
      CameraImage image, InputImageRotation rotation) async {
    if (!_isRunning || _detector == null) return;
    final inputImage = _inputImageFromCameraImage(image, rotation);
    final meshes = await _detector!.processImage(inputImage);
    onResults?.call(meshes);
  }

  /// Converts a CameraImage to NV21 InputImage accepted by ML Kit on Android.
  /// YUV_420_888 (3 planes) is manually interleaved into a single NV21 buffer.
  InputImage _inputImageFromCameraImage(
      CameraImage image, InputImageRotation rotation) {
    // Log camera format on first frame for debugging
    debugPrint('📷 Camera planes: ${image.planes.length}, '
        'format raw: ${image.format.raw}, '
        'size: ${image.width}x${image.height}');

    // Single-plane device already outputs NV21 — use directly
    if (image.planes.length == 1) {
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }

    // Convert YUV_420_888 (3 planes) → NV21 (interleaved VU)
    final int width  = image.width;
    final int height = image.height;

    final Uint8List yBytes = image.planes[0].bytes;
    final Uint8List uBytes = image.planes[1].bytes;
    final Uint8List vBytes = image.planes[2].bytes;

    final int yRowStride    = image.planes[0].bytesPerRow;
    final int uvRowStride   = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final Uint8List nv21 = Uint8List(width * height + (width * height ~/ 2));
    int idx = 0;

    // Copy Y plane row by row (strip row-stride padding)
    for (int row = 0; row < height; row++) {
      final int yOffset = row * yRowStride;
      for (int col = 0; col < width; col++) {
        nv21[idx++] = yBytes[yOffset + col];
      }
    }

    // Interleave V then U (NV21 = VU order)
    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final int uvOffset = row * uvRowStride + col * uvPixelStride;
        nv21[idx++] = vBytes[uvOffset]; // V first
        nv21[idx++] = uBytes[uvOffset]; // then U
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
}
