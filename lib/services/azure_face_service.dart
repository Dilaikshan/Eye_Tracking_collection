import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:eye_tracking_collection/models/azure_data.dart';

class AzureFaceService {
  static String get endpoint => dotenv.env['AZURE_FACE_ENDPOINT'] ?? '';
  static String get apiKey => dotenv.env['AZURE_FACE_API_KEY'] ?? '';

  bool _isProcessing = false;
  int _requestCount = 0;
  DateTime _lastRequestTime = DateTime.now();
  static const int maxRequestsPerMinute = 20;

  Future<AzureData?> processImage(InputImage inputImage) async {
    if (!_canMakeRequest() || _isProcessing) return null;

    _isProcessing = true;
    final startTime = DateTime.now();

    try {
      // Convert InputImage to JPEG bytes
      final jpegBytes = await _inputImageToJpeg(inputImage);
      if (jpegBytes == null) {
        _isProcessing = false;
        return null;
      }

      // Call Azure Face API
      final response = await http
          .post(
            Uri.parse('$endpoint/face/v1.0/detect').replace(
              queryParameters: {
                'returnFaceId': 'false',
                'returnFaceLandmarks': 'true',
                'returnFaceAttributes': 'headPose',
                'recognitionModel': 'recognition_04',
                'detectionModel': 'detection_03',
              },
            ),
            headers: {
              'Content-Type': 'application/octet-stream',
              'Ocp-Apim-Subscription-Key': apiKey,
            },
            body: jpegBytes,
          )
          .timeout(const Duration(seconds: 5));

      final latency = DateTime.now().difference(startTime).inMilliseconds;
      _requestCount++;
      _lastRequestTime = DateTime.now();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;

        if (data.isEmpty) {
          _isProcessing = false;
          return null;
        }

        final face = data.first as Map<String, dynamic>;
        _isProcessing = false;
        return _parseResponse(face, latency);
      } else {
        debugPrint('Azure error ${response.statusCode}: ${response.body}');
        _isProcessing = false;
        return null;
      }
    } catch (e) {
      debugPrint('Azure exception: $e');
      _isProcessing = false;
      return null;
    }
  }

  bool _canMakeRequest() {
    final now = DateTime.now();
    if (now.difference(_lastRequestTime).inMinutes >= 1) {
      _requestCount = 0;
      _lastRequestTime = now;
      return true;
    }
    return _requestCount < maxRequestsPerMinute;
  }

  AzureData _parseResponse(Map<String, dynamic> face, int latency) {
    final landmarks = face['faceLandmarks'] as Map<String, dynamic>?;

    Offset leftPupil = Offset.zero;
    Offset rightPupil = Offset.zero;

    if (landmarks != null) {
      final pupilLeft = landmarks['pupilLeft'] as Map<String, dynamic>?;
      final pupilRight = landmarks['pupilRight'] as Map<String, dynamic>?;

      if (pupilLeft != null) {
        leftPupil = Offset(
          pupilLeft['x']?.toDouble() ?? 0.0,
          pupilLeft['y']?.toDouble() ?? 0.0,
        );
      }

      if (pupilRight != null) {
        rightPupil = Offset(
          pupilRight['x']?.toDouble() ?? 0.0,
          pupilRight['y']?.toDouble() ?? 0.0,
        );
      }
    }

    final attributes = face['faceAttributes'] as Map<String, dynamic>?;
    final headPose = attributes?['headPose'] as Map<String, dynamic>? ?? {};

    return AzureData(
      leftPupil: leftPupil,
      rightPupil: rightPupil,
      headPose: headPose,
      eyeGaze: {}, // Not available in standard tier
      confidence: 0.85,
      latencyMs: latency,
    );
  }

  Future<Uint8List?> _inputImageToJpeg(InputImage inputImage) async {
    try {
      // Get bytes from InputImage
      final bytes = inputImage.bytes;
      if (bytes == null) return null;

      // Convert to RGB image
      final convertedImage = img.Image.fromBytes(
        width: inputImage.metadata!.size.width.toInt(),
        height: inputImage.metadata!.size.height.toInt(),
        bytes: bytes.buffer,
        format: img.Format.uint8,
      );

      // Encode as JPEG
      final jpeg = img.encodeJpg(convertedImage, quality: 85);
      return Uint8List.fromList(jpeg);
    } catch (e) {
      debugPrint('Image conversion error: $e');
      return null;
    }
  }
}
