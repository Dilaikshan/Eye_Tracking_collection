import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class EyeCropService {
  static const int _cropSize = 64;

  Future<Map<String, String?>> captureAndUpload({
    required CameraImage image,
    required Offset leftIrisCenterNorm,
    required Offset rightIrisCenterNorm,
    required String sessionId,
    required String sampleId,
  }) async {
    String? leftCropUrl;
    String? rightCropUrl;

    try {
      final leftPatch = _extractEyePatch(
        image: image,
        irisCenterNorm: leftIrisCenterNorm,
      );
      final leftJpegBytes = _encodePatchToJpeg(leftPatch);
      leftCropUrl = await _uploadCrop(
        path: 'eye_crops/$sessionId/${sampleId}_left.jpg',
        jpegBytes: leftJpegBytes,
      );
    } catch (e) {
      debugPrint('Eye crop left capture/upload failed: $e');
    }

    try {
      final rightPatch = _extractEyePatch(
        image: image,
        irisCenterNorm: rightIrisCenterNorm,
      );
      final rightJpegBytes = _encodePatchToJpeg(rightPatch);
      rightCropUrl = await _uploadCrop(
        path: 'eye_crops/$sessionId/${sampleId}_right.jpg',
        jpegBytes: rightJpegBytes,
      );
    } catch (e) {
      debugPrint('Eye crop right capture/upload failed: $e');
    }

    return {
      'leftCropUrl': leftCropUrl,
      'rightCropUrl': rightCropUrl,
    };
  }

  Uint8List _extractEyePatch({
    required CameraImage image,
    required Offset irisCenterNorm,
  }) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final yBytes = yPlane.bytes;
    final rowStride = yPlane.bytesPerRow;

    final int centerX =
        (irisCenterNorm.dx * width).toInt().clamp(0, max(0, width - 1)).toInt();
    final int centerY = (irisCenterNorm.dy * height)
        .toInt()
        .clamp(0, max(0, height - 1))
        .toInt();

    final half = _cropSize ~/ 2;
    final maxStartX = max(0, width - _cropSize);
    final maxStartY = max(0, height - _cropSize);

    final int startX = (centerX - half).clamp(0, maxStartX).toInt();
    final int startY = (centerY - half).clamp(0, maxStartY).toInt();

    final patch = Uint8List(_cropSize * _cropSize);
    var patchIndex = 0;

    for (int y = 0; y < _cropSize; y++) {
      final srcY = min(height - 1, startY + y);
      for (int x = 0; x < _cropSize; x++) {
        final srcX = min(width - 1, startX + x);
        final srcIndex = srcY * rowStride + srcX;
        patch[patchIndex++] =
            (srcIndex >= 0 && srcIndex < yBytes.length) ? yBytes[srcIndex] : 0;
      }
    }

    return patch;
  }

  Uint8List _encodePatchToJpeg(Uint8List patchBytes) {
    final grayImage = img.Image(width: _cropSize, height: _cropSize);
    for (int y = 0; y < _cropSize; y++) {
      for (int x = 0; x < _cropSize; x++) {
        final gray = patchBytes[y * _cropSize + x];
        grayImage.setPixelRgb(x, y, gray, gray, gray);
      }
    }

    final jpegBytes = img.encodeJpg(grayImage, quality: 85);
    return Uint8List.fromList(jpegBytes);
  }

  Future<String?> _uploadCrop({
    required String path,
    required Uint8List jpegBytes,
  }) async {
    try {
      final ref = FirebaseStorage.instance.ref(path);
      final snapshot = await ref.putData(jpegBytes);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Eye crop upload failed for $path: $e');
      return null;
    }
  }
}
