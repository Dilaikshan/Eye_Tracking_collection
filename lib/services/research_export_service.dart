import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Generates a research-ready CSV suitable for direct use in Python CNN training.
///
/// CSV columns (exact order for model input):
///   participant_id, session_id, timestamp, blindness_type, dominant_eye,
///   vision_acuity, wears_glasses, mode, color_label, speed_label,
///   target_x_norm, target_y_norm, target_x_px, target_y_px,
///   left_iris_x, left_iris_y, left_iris_z,
///   right_iris_x, right_iris_y, right_iris_z,
///   left_pupil_x, left_pupil_y, right_pupil_x, right_pupil_y,
///   left_ear, right_ear, ipd_normalized,
///   left_eye_inner_x, left_eye_inner_y, left_eye_outer_x, left_eye_outer_y,
///   right_eye_inner_x, right_eye_inner_y, right_eye_outer_x, right_eye_outer_y,
///   head_yaw, head_pitch, head_roll,
///   left_eye_open_prob, right_eye_open_prob,
///   face_box_left, face_box_top, face_box_right, face_box_bottom,
///   overall_confidence, ambient_light, screen_width, screen_height,
///   left_eye_crop_base64, right_eye_crop_base64
class ResearchExportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<String> _csvHeaders = [
    'participant_id',
    'session_id',
    'timestamp',
    'blindness_type',
    'dominant_eye',
    'vision_acuity',
    'wears_glasses',
    'mode',
    'color_label',
    'speed_label',
    'target_x_norm',
    'target_y_norm',
    'target_x_px',
    'target_y_px',
    'left_iris_x',
    'left_iris_y',
    'left_iris_z',
    'right_iris_x',
    'right_iris_y',
    'right_iris_z',
    'left_pupil_x',
    'left_pupil_y',
    'right_pupil_x',
    'right_pupil_y',
    'left_ear',
    'right_ear',
    'ipd_normalized',
    'left_eye_inner_x',
    'left_eye_inner_y',
    'left_eye_outer_x',
    'left_eye_outer_y',
    'right_eye_inner_x',
    'right_eye_inner_y',
    'right_eye_outer_x',
    'right_eye_outer_y',
    'head_yaw',
    'head_pitch',
    'head_roll',
    'left_eye_open_prob',
    'right_eye_open_prob',
    'face_box_left',
    'face_box_top',
    'face_box_right',
    'face_box_bottom',
    'overall_confidence',
    'ambient_light',
    'screen_width',
    'screen_height',
    'left_eye_crop_base64',
    'right_eye_crop_base64',
  ];

  /// Exports a full session to a CSV file in the Downloads/Documents folder.
  /// Returns the file path on success.
  Future<String?> exportSession({
    required String sessionId,
    required String participantId,
  }) async {
    try {
      debugPrint('✅ Starting CSV export for session $sessionId…');

      // 1. Fetch session metadata (for future use)
      // ignore: unused_local_variable
      final sessionDoc =
          await _firestore.collection('sessions').doc(sessionId).get();

      // 2. Fetch all sample chunks
      final chunksSnap = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('samples')
          .orderBy(FieldPath.documentId)
          .get();

      final allSamples = <Map<String, dynamic>>[];
      for (final chunkDoc in chunksSnap.docs) {
        final chunkData = chunkDoc.data();
        final samples = chunkData['samples'] as List<dynamic>? ?? [];
        for (final s in samples) {
          if (s is Map<String, dynamic>) allSamples.add(s);
        }
      }

      debugPrint('✅ Fetched ${allSamples.length} samples from '
          '${chunksSnap.docs.length} chunks');

      if (allSamples.isEmpty) {
        debugPrint('⚠️ No samples found for session $sessionId');
        return null;
      }

      // 3. Build CSV content
      final buffer = StringBuffer();
      buffer.writeln(_csvHeaders.join(','));

      for (final sample in allSamples) {
        final row = _sampleToCsvRow(
          sample: sample,
          sessionId: sessionId,
          participantId: participantId,
        );
        buffer.writeln(row);
      }

      // 4. Write to file
      final directory = await _getExportDirectory();
      final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final safeParticipant = participantId.replaceAll(RegExp(r'[^\w]'), '_');
      final fileName = 'eye_tracking_${safeParticipant}_$dateStr.csv';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(buffer.toString(), encoding: utf8);

      debugPrint('✅ CSV exported: $filePath');
      debugPrint(
          '   Rows: ${allSamples.length}, Size: ${file.lengthSync()} bytes');

      return filePath;
    } catch (e) {
      debugPrint('❌ Export failed: $e');
      return null;
    }
  }

  String _sampleToCsvRow({
    required Map<String, dynamic> sample,
    required String sessionId,
    required String participantId,
  }) {
    final target = sample['target'] as Map<String, dynamic>? ?? {};
    final mediapipe = sample['mediapipe'] as Map<String, dynamic>? ?? {};
    final mlkit = sample['mlkit'] as Map<String, dynamic>? ?? {};
    final deviceInfo = sample['deviceInfo'] as Map<String, dynamic>? ?? {};
    final quality = sample['quality'] as Map<String, dynamic>? ?? {};
    final participantCtx =
        sample['participantContext'] as Map<String, dynamic>? ?? {};

    final mpCorners = mediapipe['eyeCorners'] as Map<String, dynamic>? ?? {};
    final mpLeftInner = mpCorners['leftInner'] as Map<String, dynamic>? ?? {};
    final mpLeftOuter = mpCorners['leftOuter'] as Map<String, dynamic>? ?? {};
    final mpRightInner = mpCorners['rightInner'] as Map<String, dynamic>? ?? {};
    final mpRightOuter = mpCorners['rightOuter'] as Map<String, dynamic>? ?? {};

    final mpFaceBox = mediapipe['faceBox'] as Map<String, dynamic>? ?? {};
    final mlkitHeadPose = mlkit['headPose'] as Map<String, dynamic>? ?? {};

    final leftPupil =
        mediapipe['leftPupilCenter'] as Map<String, dynamic>? ?? {};
    final rightPupil =
        mediapipe['rightPupilCenter'] as Map<String, dynamic>? ?? {};

    // MediaPipe iris center stored as leftIrisCenter normalized [0,1]
    final leftIrisCenter =
        mediapipe['leftIrisCenter'] as Map<String, dynamic>? ?? {};
    final rightIrisCenter =
        mediapipe['rightIrisCenter'] as Map<String, dynamic>? ?? {};

    final values = [
      _esc(participantId),
      _esc(sessionId),
      sample['timestamp']?.toString() ?? '',
      _esc(participantCtx['blindnessType']?.toString() ?? ''),
      _esc(participantCtx['dominantEye']?.toString() ?? ''),
      participantCtx['visionAcuity']?.toString() ?? '',
      participantCtx['wearsGlasses']?.toString() ?? '',
      _esc(sample['mode']?.toString() ?? ''),
      _esc(sample['colorLabel']?.toString() ?? ''),
      _esc(sample['speedLabel']?.toString() ?? ''),
      // target
      target['normalizedX']?.toString() ?? '0',
      target['normalizedY']?.toString() ?? '0',
      target['pixelX']?.toString() ?? '0',
      target['pixelY']?.toString() ?? '0',
      // iris centers (normalized [0,1])
      leftIrisCenter['x']?.toString() ?? '0',
      leftIrisCenter['y']?.toString() ?? '0',
      mediapipe['leftIrisDepth']?.toString() ?? '0',
      rightIrisCenter['x']?.toString() ?? '0',
      rightIrisCenter['y']?.toString() ?? '0',
      mediapipe['rightIrisDepth']?.toString() ?? '0',
      // pupils (pixel)
      leftPupil['pixelX']?.toString() ?? '0',
      leftPupil['pixelY']?.toString() ?? '0',
      rightPupil['pixelX']?.toString() ?? '0',
      rightPupil['pixelY']?.toString() ?? '0',
      // EAR
      mediapipe['leftEAR']?.toString() ?? '0',
      mediapipe['rightEAR']?.toString() ?? '0',
      mediapipe['ipdNormalized']?.toString() ?? '0',
      // eye corners
      mpLeftInner['x']?.toString() ?? '0',
      mpLeftInner['y']?.toString() ?? '0',
      mpLeftOuter['x']?.toString() ?? '0',
      mpLeftOuter['y']?.toString() ?? '0',
      mpRightInner['x']?.toString() ?? '0',
      mpRightInner['y']?.toString() ?? '0',
      mpRightOuter['x']?.toString() ?? '0',
      mpRightOuter['y']?.toString() ?? '0',
      // head pose
      mlkitHeadPose['yaw']?.toString() ?? '0',
      mlkitHeadPose['pitch']?.toString() ?? '0',
      mlkitHeadPose['roll']?.toString() ?? '0',
      // eye open probability
      mlkit['leftEyeOpenProb']?.toString() ?? '0',
      mlkit['rightEyeOpenProb']?.toString() ?? '0',
      // face box
      mpFaceBox['left']?.toString() ?? '0',
      mpFaceBox['top']?.toString() ?? '0',
      mpFaceBox['right']?.toString() ?? '0',
      mpFaceBox['bottom']?.toString() ?? '0',
      // quality / context
      quality['overallConfidence']?.toString() ?? '0',
      '0', // ambient_light placeholder
      deviceInfo['screenWidthPixels']?.toString() ?? '0',
      deviceInfo['screenHeightPixels']?.toString() ?? '0',
      // eye crops (large base64 – may be empty)
      _esc(mediapipe['leftEyeCrop']?.toString() ?? ''),
      _esc(mediapipe['rightEyeCrop']?.toString() ?? ''),
    ];

    return values.join(',');
  }

  /// Escape a string for CSV: wrap in quotes and escape internal quotes.
  String _esc(String value) {
    if (value.isEmpty) return '';
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<Directory> _getExportDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Try Downloads first
        final downloads = Directory('/storage/emulated/0/Download');
        if (await downloads.exists()) return downloads;
      }
      // Fallback to app documents directory
      return getApplicationDocumentsDirectory();
    } catch (_) {
      return getApplicationDocumentsDirectory();
    }
  }

  /// Quick summary statistics for a session (used in summary screen).
  Future<Map<String, dynamic>> getSessionStats(String sessionId) async {
    try {
      final chunksSnap = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('samples')
          .orderBy(FieldPath.documentId)
          .get();

      int total = 0;
      int withCrops = 0;
      double totalConf = 0;
      double totalEAR = 0;
      int blinks = 0;
      final phaseCounts = <String, int>{};

      for (final chunkDoc in chunksSnap.docs) {
        final samples = (chunkDoc.data()['samples'] as List<dynamic>? ?? []);
        for (final s in samples) {
          if (s is! Map<String, dynamic>) continue;
          total++;
          final mp = s['mediapipe'] as Map<String, dynamic>? ?? {};
          final quality = s['quality'] as Map<String, dynamic>? ?? {};

          if (mp['leftEyeCrop'] != null) withCrops++;
          totalConf += (quality['overallConfidence'] as num? ?? 0).toDouble();
          final ear =
              ((mp['leftEAR'] as num? ?? 0) + (mp['rightEAR'] as num? ?? 0)) /
                  2;
          totalEAR += ear;
          if (quality['blink'] == true) blinks++;

          final mode = s['mode'] as String? ?? 'unknown';
          phaseCounts[mode] = (phaseCounts[mode] ?? 0) + 1;
        }
      }

      return {
        'total': total,
        'withCrops': withCrops,
        'avgConfidence': total > 0 ? totalConf / total : 0.0,
        'avgEAR': total > 0 ? totalEAR / total : 0.0,
        'blinkCount': blinks,
        'phaseCounts': phaseCounts,
      };
    } catch (e) {
      debugPrint('❌ getSessionStats error: $e');
      return {};
    }
  }
}
