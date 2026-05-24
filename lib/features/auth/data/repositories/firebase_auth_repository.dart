import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<AuthSession?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_mapUser);
  }

  @override
  AuthSession? currentSession() {
    return _mapUser(_firebaseAuth.currentUser);
  }

  @override
  Future<String> currentIdToken({bool forceRefresh = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated Firebase user is available.');
    }

    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw StateError('Unable to obtain a Firebase ID token.');
    }

    return token;
  }

  @override
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final session = _mapUser(credential.user);
    if (session == null) {
      throw StateError('Firebase did not return an authenticated user.');
    }

    return session;
  }

  @override
  Future<AuthSession> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase did not return a created user.');
    }

    final trimmedDisplayName = displayName?.trim();
    if (trimmedDisplayName != null && trimmedDisplayName.isNotEmpty) {
      await user.updateDisplayName(trimmedDisplayName);
      await user.reload();
    }

    final session = _mapUser(_firebaseAuth.currentUser);
    if (session == null) {
      throw StateError('Firebase did not return an authenticated user.');
    }

    return session;
  }

  @override
  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }

  AuthSession? _mapUser(User? user) {
    if (user == null) {
      return null;
    }

    return AuthSession(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}
