import 'dart:typed_data';
import 'dart:ui' as ui;

import '../data/models/fighter_config.dart';
import 'app_services.dart';

/// Downloads selfie textures from Firebase Storage once and keeps the decoded
/// [ui.Image] in memory so both Flutter widgets and the Flame engine can draw
/// them every frame.
class FaceCache {
  FaceCache._();
  static final instance = FaceCache._();

  final _images = <String, ui.Image>{};
  final _pending = <String, Future<ui.Image?>>{};

  String _key(FighterConfig c) =>
      '${c.id}|${c.faceImagePath}|${c.updatedAt?.millisecondsSinceEpoch}';

  ui.Image? peek(FighterConfig c) => c.hasFace ? _images[_key(c)] : null;

  Future<ui.Image?> load(FighterConfig c) {
    final path = c.faceImagePath;
    if (path == null) return Future.value(null);
    final key = _key(c);
    final cached = _images[key];
    if (cached != null) return Future.value(cached);
    return _pending.putIfAbsent(key, () async {
      try {
        final bytes = await AppServices.faces.downloadFace(path);
        if (bytes == null) return null;
        final img = await decode(bytes);
        _images[key] = img;
        return img;
      } catch (_) {
        return null; // missing / no permission -> draw default face
      } finally {
        _pending.remove(key);
      }
    });
  }

  /// Seed the cache right after an upload so we don't re-download.
  Future<ui.Image> put(FighterConfig c, Uint8List bytes) async {
    final img = await decode(bytes);
    _images[_key(c)] = img;
    return img;
  }

  /// Loads faces for several fighters, keyed by fighter id.
  Future<Map<String, ui.Image>> loadAll(Iterable<FighterConfig> configs) async {
    final out = <String, ui.Image>{};
    for (final c in configs) {
      final img = await load(c);
      if (img != null) out[c.id] = img;
    }
    return out;
  }

  static Future<ui.Image> decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
