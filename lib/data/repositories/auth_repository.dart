import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../models/app_user.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class AuthRepository {
  AppUser? get currentUser;
  Stream<AppUser?> authStateChanges();
  Future<void> signIn({required String email, required String password});
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  });
  Future<void> signInAsGuest();
  Future<void> signOut();
}

// ---------------------------------------------------------------------------
// Firebase implementation
// ---------------------------------------------------------------------------

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth})
      : _auth = auth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;

  AppUser? _map(fb.User? u) {
    if (u == null) return null;
    final fallback = u.isAnonymous
        ? 'Guest-${u.uid.substring(0, 4).toUpperCase()}'
        : (u.email?.split('@').first ?? 'Fighter');
    final name = u.displayName;
    return AppUser(
      uid: u.uid,
      displayName: (name == null || name.isEmpty) ? fallback : name,
      email: u.email,
      isGuest: u.isAnonymous,
    );
  }

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  // userChanges() (unlike authStateChanges) also fires after
  // updateDisplayName, so the menu shows the right name after registering.
  @override
  Stream<AppUser?> authStateChanges() => _auth.userChanges().map(_map);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email, password: password));

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);
        await cred.user?.updateDisplayName(displayName);
      });

  @override
  Future<void> signInAsGuest() => _guard(() => _auth.signInAnonymously());

  @override
  Future<void> signOut() => _auth.signOut();

  Future<void> _guard(Future<Object?> Function() action) async {
    try {
      await action();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(_friendly(e));
    }
  }

  String _friendly(fb.FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address looks invalid.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Wrong email or password.',
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'Password must be at least 6 characters.',
        'operation-not-allowed' =>
          'Enable this sign-in method in the Firebase console (Authentication > Sign-in method).',
        'network-request-failed' => 'No internet connection.',
        _ => e.message ?? 'Sign-in failed (${e.code}).',
      };
}

// ---------------------------------------------------------------------------
// Offline implementation (used when Firebase isn't configured yet)
// ---------------------------------------------------------------------------

class LocalAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  void _set(AppUser? u) {
    _user = u;
    _controller.add(u);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (!email.contains('@')) throw const AuthFailure('That email address looks invalid.');
    _set(AppUser(
      uid: 'local_${email.hashCode.toUnsigned(32).toRadixString(36)}',
      displayName: email.split('@').first,
      email: email,
    ));
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    if (password.length < 6) {
      throw const AuthFailure('Password must be at least 6 characters.');
    }
    _set(AppUser(
      uid: 'local_${email.hashCode.toUnsigned(32).toRadixString(36)}',
      displayName: displayName,
      email: email,
    ));
  }

  @override
  Future<void> signInAsGuest() async {
    final tag = Random().nextInt(0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0');
    _set(AppUser(uid: 'guest_$tag', displayName: 'Guest-$tag', isGuest: true));
  }

  @override
  Future<void> signOut() async => _set(null);
}
