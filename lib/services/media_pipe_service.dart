import 'package:camera/camera.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:flutter/foundation.dart' show WriteBuffer;
import 'package:flutter/painting.dart' show Size;

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

  Future<void> processCameraImage(CameraImage image, InputImageRotation rotation) async {
    if (!_isRunning || _detector == null) return;
    final inputImage = _inputImageFromCameraImage(image, rotation);
    final meshes = await _detector!.processImage(inputImage);
    onResults?.call(meshes);
  }

  InputImage _inputImageFromCameraImage(CameraImage image, InputImageRotation rotation) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final imageRotation = rotation;

    final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }
}
