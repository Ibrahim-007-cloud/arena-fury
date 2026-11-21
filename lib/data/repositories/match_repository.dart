import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/match_record.dart';
import '../models/player_stats.dart';
import 'firestore_utils.dart';

abstract class MatchRepository {
  Future<void> ensureProfile(AppUser user);
  Future<void> recordMatch(AppUser user, MatchRecord record);
  Stream<PlayerStats> watchPlayerStats(AppUser user);
  Stream<List<MatchRecord>> watchRecentMatches(String uid, {int limit = 10});
  Stream<List<PlayerStats>> watchLeaderboard({int limit = 25});
}

class FirebaseMatchRepository implements MatchRepository {
  FirebaseMatchRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<void> ensureProfile(AppUser user) => _user(user.uid).set({
        'displayName': user.displayName,
        'email': user.email,
        'isGuest': user.isGuest,
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Writes the match and bumps the aggregate counters on both the private
  /// profile and the public leaderboard in one atomic batch.
  @override
  Future<void> recordMatch(AppUser user, MatchRecord record) async {
    final batch = _db.batch();
    final matchRef = _user(user.uid).collection('matches').doc();
    batch.set(matchRef, record.toMap()..['playedAt'] = FieldValue.serverTimestamp());

    final counters = <String, dynamic>{
      'displayName': user.displayName,
      'wins': FieldValue.increment(record.outcome == MatchOutcome.win ? 1 : 0),
      'losses': FieldValue.increment(record.outcome == MatchOutcome.loss ? 1 : 0),
      'draws': FieldValue.increment(record.outcome == MatchOutcome.draw ? 1 : 0),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.set(_user(user.uid), counters, SetOptions(merge: true));
    batch.set(_db.collection('leaderboard').doc(user.uid), counters,
        SetOptions(merge: true));
    await batch.commit();
  }

  @override
  Stream<PlayerStats> watchPlayerStats(AppUser user) => _user(user.uid)
      .snapshots()
      .map((d) => PlayerStats.fromMap(user.uid, d.data() ?? const {},
          fallbackName: user.displayName));

  @override
  Stream<List<MatchRecord>> watchRecentMatches(String uid, {int limit = 10}) =>
      _user(uid)
          .collection('matches')
          .orderBy('playedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs
              .map((d) => MatchRecord.fromMap(d.id, normalizeTimestamps(d.data())))
              .toList());

  @override
  Stream<List<PlayerStats>> watchLeaderboard({int limit = 25}) => _db
      .collection('leaderboard')
      .orderBy('wins', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => PlayerStats.fromMap(d.id, d.data())).toList());
}

class LocalMatchRepository implements MatchRepository {
  final _stats = <String, PlayerStats>{};
  final _matches = <String, List<MatchRecord>>{};
  final _changes = StreamController<void>.broadcast();

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Future<void> ensureProfile(AppUser user) async {
    _stats.putIfAbsent(
        user.uid, () => PlayerStats(uid: user.uid, displayName: user.displayName));
  }

  @override
  Future<void> recordMatch(AppUser user, MatchRecord record) async {
    final s = _stats[user.uid] ?? PlayerStats(uid: user.uid, displayName: user.displayName);
    _stats[user.uid] = s.copyWith(
      wins: s.wins + (record.outcome == MatchOutcome.win ? 1 : 0),
      losses: s.losses + (record.outcome == MatchOutcome.loss ? 1 : 0),
      draws: s.draws + (record.outcome == MatchOutcome.draw ? 1 : 0),
    );
    _matches.putIfAbsent(user.uid, () => []).insert(0, record);
    _changes.add(null);
  }

  @override
  Stream<PlayerStats> watchPlayerStats(AppUser user) => _watch(() =>
      _stats[user.uid] ?? PlayerStats(uid: user.uid, displayName: user.displayName));

  @override
  Stream<List<MatchRecord>> watchRecentMatches(String uid, {int limit = 10}) =>
      _watch(() => (_matches[uid] ?? const <MatchRecord>[]).take(limit).toList());

  @override
  Stream<List<PlayerStats>> watchLeaderboard({int limit = 25}) => _watch(() {
        final list = _stats.values.toList()..sort((a, b) => b.wins.compareTo(a.wins));
        return list.take(limit).toList();
      });
}
