import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/fighter_config.dart';
import '../roster.dart';
import 'firestore_utils.dart';

class SlotLimitReached implements Exception {
  const SlotLimitReached();
  @override
  String toString() =>
      'All ${BuiltInRoster.maxCustomSlots} custom fighter slots are used. '
      'Edit or delete an existing custom fighter first.';
}

/// Custom fighters live at users/{uid}/fighters/{fighterId}.
abstract class FighterRepository {
  Stream<List<FighterConfig>> watchCustomFighters(String uid);
  Future<int> countCustomFighters(String uid);
  Future<void> saveFighter(String uid, FighterConfig fighter, {required bool isNew});
  Future<void> deleteFighter(String uid, String fighterId);
}

class FirebaseFighterRepository implements FighterRepository {
  FirebaseFighterRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('fighters');

  @override
  Stream<List<FighterConfig>> watchCustomFighters(String uid) => _col(uid)
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => FighterConfig.fromMap(d.id, normalizeTimestamps(d.data())))
          .toList());

  @override
  Future<int> countCustomFighters(String uid) async =>
      (await _col(uid).get()).docs.length;

  @override
  Future<void> saveFighter(String uid, FighterConfig fighter,
      {required bool isNew}) async {
    if (isNew && await countCustomFighters(uid) >= BuiltInRoster.maxCustomSlots) {
      throw const SlotLimitReached();
    }
    // updatedAt is a client DateTime (set by the Studio) so the face-texture
    // cache key stays stable instead of flipping null -> server time.
    await _col(uid).doc(fighter.id).set(fighter.toMap());
  }

  @override
  Future<void> deleteFighter(String uid, String fighterId) =>
      _col(uid).doc(fighterId).delete();
}

class LocalFighterRepository implements FighterRepository {
  final _store = <String, Map<String, FighterConfig>>{};
  final _changes = StreamController<void>.broadcast();

  List<FighterConfig> _list(String uid) {
    final list = (_store[uid]?.values.toList() ?? <FighterConfig>[])
      ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return list;
  }

  @override
  Stream<List<FighterConfig>> watchCustomFighters(String uid) async* {
    yield _list(uid);
    await for (final _ in _changes.stream) {
      yield _list(uid);
    }
  }

  @override
  Future<int> countCustomFighters(String uid) async => _store[uid]?.length ?? 0;

  @override
  Future<void> saveFighter(String uid, FighterConfig fighter,
      {required bool isNew}) async {
    final map = _store.putIfAbsent(uid, () => {});
    if (isNew && map.length >= BuiltInRoster.maxCustomSlots) {
      throw const SlotLimitReached();
    }
    map[fighter.id] = fighter;
    _changes.add(null);
  }

  @override
  Future<void> deleteFighter(String uid, String fighterId) async {
    _store[uid]?.remove(fighterId);
    _changes.add(null);
  }
}
