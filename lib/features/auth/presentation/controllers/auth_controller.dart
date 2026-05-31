import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../bootstrap/dependency_injection.dart';
import '../../../../core/network/authenticated_api_client.dart';
import '../../../notes/data/models/notes_store_model.dart';
import '../../auth_providers.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    ref.read(authStartupNoticeProvider.notifier).state = null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithEmail(
            email: email,
            password: password,
          );
    });
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    ref.read(authStartupNoticeProvider.notifier).state = null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signUpWithEmail(
            email: email,
            password: password,
            displayName: displayName,
          );
    });
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(
            email: email,
          );
    });
  }

  Future<void> sendEmailVerification() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      await ref.read(authRepositoryProvider).reloadSession();
    });
  }

  Future<void> refreshSession() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).reloadSession();
    });
  }

  Future<void> signOut() async {
    ref.read(authStartupNoticeProvider.notifier).state = null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
    });
  }

  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authenticatedApiClientProvider).deleteJson('/account');
      await ref
          .read(notesRepositoryProvider)
          .replaceStore(NotesStoreModel.empty());
      await ref.read(authRepositoryProvider).signOut();
    });
  }
}
