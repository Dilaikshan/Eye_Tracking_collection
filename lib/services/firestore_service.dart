import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eye_tracking_collection/models/user_profile.dart';
import 'package:flutter/painting.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<String> startSession({
    required UserProfile profile,
    required Size screenSize,
    required bool consentGiven,
  }) async {
    final sessionId = _db.collection('sessions').doc().id;
    final sessionRef = _db.collection('users').doc(profile.name.isEmpty ? 'guest' : profile.name).collection('sessions').doc(sessionId);
    await sessionRef.set({
      'sessionId': sessionId,
      'consentGiven': consentGiven,
      'consentTimestamp': DateTime.now().millisecondsSinceEpoch,
      'startedAt': DateTime.now().millisecondsSinceEpoch,
      'device': {
        'model': 'unknown',
        'screenWidth': screenSize.width,
        'screenHeight': screenSize.height,
      },
      'calibration': {},
      'user': {
        'name': profile.name,
        'age': profile.age,
        'blindnessType': profile.blindnessType,
        'languageCode': profile.languageCode,
      },
    });
    return sessionId;
  }

  Future<void> saveCalibration({required String userId, required String sessionId, required Map<String, dynamic> calibration}) async {
    final sessionRef = _db.collection('users').doc(userId).collection('sessions').doc(sessionId);
    await sessionRef.update({'calibration': calibration});
  }

  Future<void> addSamples({required String userId, required String sessionId, required List<Map<String, dynamic>> samples, required int chunkIndex}) async {
    final chunkId = 'chunk_${chunkIndex.toString().padLeft(3, '0')}';
    final chunkRef = _db.collection('users').doc(userId).collection('sessions').doc(sessionId).collection('samples').doc(chunkId);
    await chunkRef.set({
      'chunkId': chunkId,
      'samples': samples,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
