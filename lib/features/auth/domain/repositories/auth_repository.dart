import '../entities/auth_session.dart';

abstract class AuthRepository {
  Stream<AuthSession?> authStateChanges();
  AuthSession? currentSession();
  Future<String> currentIdToken({bool forceRefresh = false});
  Future<AuthSession> reloadSession();
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  });
  Future<AuthSession> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  });
  Future<void> sendPasswordResetEmail({required String email});
  Future<void> sendEmailVerification();
  Future<void> signOut();
}
