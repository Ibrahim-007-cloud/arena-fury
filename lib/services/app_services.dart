import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/face_storage_repository.dart';
import '../data/repositories/fighter_repository.dart';
import '../data/repositories/match_repository.dart';
import '../firebase_options.dart';

/// Tiny service locator. Picks Firebase-backed repositories when Firebase
/// initialises, otherwise falls back to in-memory ones (offline demo mode).
abstract final class AppServices {
  static bool firebaseReady = false;
  static String? firebaseError;

  static late final AuthRepository auth;
  static late final FighterRepository fighters;
  static late final MatchRepository matches;
  static late final FaceStorageRepository faces;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      firebaseReady = true;
    } catch (e) {
      firebaseError = e.toString();
      debugPrint('Firebase unavailable, starting in offline demo mode: $e');
    }

    if (firebaseReady) {
      auth = FirebaseAuthRepository();
      fighters = FirebaseFighterRepository();
      matches = FirebaseMatchRepository();
      faces = FirebaseFaceStorageRepository();
    } else {
      auth = LocalAuthRepository();
      fighters = LocalFighterRepository();
      matches = LocalMatchRepository();
      faces = LocalFaceStorageRepository();
    }
  }
}
