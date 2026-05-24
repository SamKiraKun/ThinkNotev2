import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/firebase_auth_repository.dart';
import 'domain/entities/auth_session.dart';
import 'domain/repositories/auth_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(ref.watch(firebaseAuthProvider));
});

final authSessionChangesProvider = StreamProvider<AuthSession?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentAuthSessionProvider = Provider<AuthSession?>((ref) {
  return ref.watch(authSessionChangesProvider).valueOrNull ??
      ref.watch(authRepositoryProvider).currentSession();
});
