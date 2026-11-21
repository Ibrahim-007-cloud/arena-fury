import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class FaceUpload {
  const FaceUpload({required this.path, this.url});
  final String path;
  final String? url;
}

/// Cropped selfie textures live at users/{uid}/faces/{fighterId}.png
abstract class FaceStorageRepository {
  Future<FaceUpload> uploadFace(String uid, String fighterId, Uint8List pngBytes);
  Future<Uint8List?> downloadFace(String path);
  Future<void> deleteFace(String path);
}

class FirebaseFaceStorageRepository implements FaceStorageRepository {
  FirebaseFaceStorageRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  static const _maxBytes = 2 * 1024 * 1024;

  @override
  Future<FaceUpload> uploadFace(String uid, String fighterId, Uint8List pngBytes) async {
    final path = 'users/$uid/faces/$fighterId.png';
    final ref = _storage.ref(path);
    await ref.putData(pngBytes, SettableMetadata(contentType: 'image/png'));
    final url = await ref.getDownloadURL();
    return FaceUpload(path: path, url: url);
  }

  @override
  Future<Uint8List?> downloadFace(String path) => _storage.ref(path).getData(_maxBytes);

  @override
  Future<void> deleteFace(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}

class LocalFaceStorageRepository implements FaceStorageRepository {
  final _files = <String, Uint8List>{};

  @override
  Future<FaceUpload> uploadFace(String uid, String fighterId, Uint8List pngBytes) async {
    final path = 'users/$uid/faces/$fighterId.png';
    _files[path] = pngBytes;
    return FaceUpload(path: path);
  }

  @override
  Future<Uint8List?> downloadFace(String path) async => _files[path];

  @override
  Future<void> deleteFace(String path) async => _files.remove(path);
}
