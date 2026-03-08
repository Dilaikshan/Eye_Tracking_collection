import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eye_tracking_collection/models/user_profile.dart';
import 'package:flutter/material.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Start a new data collection session
  Future<String> startSession({
    required UserProfile profile,
    required Size screenSize,
    required bool consentGiven,
  }) async {
    try {
      final sessionRef = await _firestore.collection('sessions').add({
        'userId': profile.name,
        'participantProfile': profile.toMap(),
        'screenSize': {
          'width': screenSize.width,
          'height': screenSize.height,
        },
        'consentGiven': consentGiven,
        'startTime': FieldValue.serverTimestamp(),
        'status': 'active',
        'totalSamples': 0,
      });

      debugPrint('✓ Session started: ${sessionRef.id}');
      return sessionRef.id;
    } catch (e) {
      debugPrint('❌ Error starting session: $e');
      rethrow;
    }
  }

  /// Add batch of samples to session
  Future<void> addSamples({
    required String userId,
    required String sessionId,
    required List<Map<String, dynamic>> samples,
    required int chunkIndex,
  }) async {
    try {
      final batch = _firestore.batch();

      // Create chunk document
      final chunkRef = _firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('samples')
          .doc('chunk_$chunkIndex');

      batch.set(chunkRef, {
        'chunkIndex': chunkIndex,
        'sampleCount': samples.length,
        'timestamp': FieldValue.serverTimestamp(),
        'samples': samples,
      });

      // Update session total
      final sessionRef = _firestore.collection('sessions').doc(sessionId);
      batch.update(sessionRef, {
        'totalSamples': FieldValue.increment(samples.length),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('✓ Saved ${samples.length} samples (chunk $chunkIndex)');
    } catch (e) {
      debugPrint('❌ Error saving samples: $e');
      rethrow;
    }
  }

  /// End session
  Future<void> endSession(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'status': 'completed',
        'endTime': FieldValue.serverTimestamp(),
      });

      debugPrint('✓ Session ended: $sessionId');
    } catch (e) {
      debugPrint('❌ Error ending session: $e');
    }
  }

  /// Get session statistics
  Future<Map<String, dynamic>> getSessionStats(String sessionId) async {
    try {
      final sessionDoc =
          await _firestore.collection('sessions').doc(sessionId).get();
      return sessionDoc.data() ?? {};
    } catch (e) {
      debugPrint('❌ Error getting session stats: $e');
      return {};
    }
  }
}
