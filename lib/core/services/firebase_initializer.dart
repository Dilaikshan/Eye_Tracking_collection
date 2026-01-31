import 'package:firebase_core/firebase_core.dart';
import 'package:eye_tracking_collection/firebase_options.dart';

class FirebaseInitializer {
  static Future<FirebaseApp> init() async {
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
