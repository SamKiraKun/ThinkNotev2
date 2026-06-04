import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinknote/core/router/app_router.dart';
import 'package:thinknote/core/storage/local_storage.dart';
import 'package:thinknote/core/theme/app_theme.dart';
import 'package:thinknote/features/auth/auth_providers.dart';
import 'package:thinknote/features/auth/presentation/controllers/auth_controller.dart';
import 'package:thinknote/features/auth/presentation/screens/auth_gate_screen.dart';
import 'package:thinknote/features/folders/data/models/folder_model.dart';
import 'package:thinknote/features/folders/data/models/tag_model.dart';
import 'package:thinknote/features/notes/data/models/app_preferences_model.dart';
import 'package:thinknote/features/notes/data/models/note_model.dart';
import 'package:thinknote/features/notes/presentation/controllers/notes_controller.dart';
import 'package:thinknote/features/notes/presentation/controllers/notes_state.dart';
import 'package:thinknote/features/onboarding/data/models/onboarding_profile.dart';
import 'package:thinknote/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:thinknote/features/onboarding/presentation/screens/onboarding_experience_screen.dart';

late SharedPreferences sharedPreferences;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
  });

  setUp(() async {
    await sharedPreferences.clear();
  });

  testWidgets('launch routing sends incomplete workspaces to onboarding',
      (tester) async {
    final onboardingController =
        _FakeOnboardingController(OnboardingProfile.initial());

    await _pumpRouter(
      tester,
      overrides: [
        appStartupSnapshotProvider.overrideWith(
          (ref) async => AppStartupSnapshot(
            onboardingProfile: OnboardingProfile.initial(),
            requiresAuthentication: false,
          ),
        ),
        onboardingControllerProvider.overrideWith(() => onboardingController),
      ],
    );

    expect(find.text('ThinkNote'), findsWidgets);
    expect(
      find.text('Write anything instantly.'),
      findsOneWidget,
    );
  });

  testWidgets('launch routing opens the dashboard for completed workspaces',
      (tester) async {
    final onboardingProfile = _completedProfile();

    await _pumpRouter(
      tester,
      overrides: [
        appStartupSnapshotProvider.overrideWith(
          (ref) async => AppStartupSnapshot(
            onboardingProfile: onboardingProfile,
            requiresAuthentication: false,
          ),
        ),
        onboardingControllerProvider.overrideWith(
          () => _FakeOnboardingController(onboardingProfile),
        ),
        notesControllerProvider.overrideWith(
          () => _FakeNotesController(_sampleNotesState()),
        ),
      ],
    );

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Recent work'), findsOneWidget);
    expect(
      find.textContaining('Track active work, decisions, and reference notes in one workspace.'),
      findsOneWidget,
    );
  });

  testWidgets('completed workspaces redirect to auth gate at launch when unauthenticated',
      (tester) async {
    final onboardingProfile = _completedProfile();

    await _pumpRouter(
      tester,
      overrides: [
        appStartupSnapshotProvider.overrideWith(
          (ref) async => AppStartupSnapshot(
            onboardingProfile: onboardingProfile,
            requiresAuthentication: true,
          ),
        ),
        onboardingControllerProvider.overrideWith(
          () => _FakeOnboardingController(onboardingProfile),
        ),
        notesControllerProvider.overrideWith(
          () => _FakeNotesController(_sampleNotesState()),
        ),
      ],
    );

    expect(find.byType(AuthGateScreen), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('onboarding completion submits default workspace choices',
      (tester) async {
    final onboardingController =
        _FakeOnboardingController(OnboardingProfile.initial());

    await _pumpScreen(
      tester,
      const OnboardingExperienceScreen(),
      overrides: [
        onboardingControllerProvider.overrideWith(() => onboardingController),
      ],
    );

    expect(find.text('Write anything instantly.'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Designed for your ideas.'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Private and secure.'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(onboardingController.completedWorkspaceName, 'My Workspace');
    expect(onboardingController.completedFocus, WorkspaceFocus.capture);
    expect(onboardingController.completedTheme, AppThemePreference.system);
    expect(onboardingController.completedNotifications, isFalse);
  });

  testWidgets('get started opens auth gate without a long launch delay',
      (tester) async {
    await _pumpRouter(tester);

    expect(find.text('Write anything instantly.'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(AuthGateScreen), findsOneWidget);
    expect(find.text('Sign in to continue.'), findsOneWidget);
  });

  testWidgets('auth screen supports password reset and verification guidance',
      (tester) async {
    final authController = _FakeAuthController();

    await _pumpScreen(
      tester,
      const AuthGateScreen(),
      overrides: [
        authControllerProvider.overrideWith(() => authController),
      ],
    );

    await tester.ensureVisible(find.text('Forgot Password?'));
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'sam@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send Reset Link'));
    await tester.pumpAndSettle();

    expect(authController.passwordResetEmail, 'sam@example.com');
    expect(find.text('Reset password'), findsNothing);

    await tester.tap(find.text('Create Account').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('verification link'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(0), 'Sam');
    await tester.enterText(find.byType(TextField).at(1), 'sam@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(authController.signUpEmail, 'sam@example.com');
    expect(authController.signUpDisplayName, 'Sam');
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        currentAuthSessionProvider.overrideWithValue(null),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRouter(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        currentAuthSessionProvider.overrideWithValue(null),
        ...overrides,
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final router = ref.watch(appRouterProvider);
          return MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          );
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

OnboardingProfile _completedProfile() {
  return const OnboardingProfile(
    hasCompletedOnboarding: true,
    workspaceName: 'Studio HQ',
    workspaceFocus: WorkspaceFocus.planning,
    wantsNotifications: false,
    themePreference: AppThemePreference.system,
  );
}

NotesState _sampleNotesState() {
  final timestamp = DateTime.utc(2026, 5, 25, 10);
  final folder = FolderModel(
    id: 'product',
    name: 'Product Ops',
    colorKey: 'work',
    emoji: 'P',
    createdAt: timestamp,
    updatedAt: timestamp,
  );
  final tag = TagModel(
    id: 'launch',
    label: 'Launch',
    createdAt: timestamp,
    updatedAt: timestamp,
    emoji: 'L',
  );

  return NotesState(
    notes: [
      NoteModel(
        id: 'note-1',
        title: 'Launch brief',
        content: 'Outline the rollout milestones and key risks.',
        createdAt: timestamp,
        updatedAt: timestamp,
        folderId: folder.id,
        tags: const ['Launch'],
        isPinned: true,
        isFavorite: true,
      ),
    ],
    folders: [folder],
    tags: [tag],
    recentSearches: const ['rollout'],
    preferences: const AppPreferencesModel(),
  );
}

class _FakeOnboardingController extends OnboardingController {
  _FakeOnboardingController(this.profile);

  final OnboardingProfile profile;
  String? completedWorkspaceName;
  WorkspaceFocus? completedFocus;
  bool? completedNotifications;
  AppThemePreference? completedTheme;

  @override
  Future<OnboardingProfile> build() async => profile;

  @override
  Future<void> completeOnboarding({
    required String workspaceName,
    required WorkspaceFocus workspaceFocus,
    required bool wantsNotifications,
    required AppThemePreference themePreference,
  }) async {
    completedWorkspaceName = workspaceName;
    completedFocus = workspaceFocus;
    completedNotifications = wantsNotifications;
    completedTheme = themePreference;
    state = AsyncData(
      profile.copyWith(
        hasCompletedOnboarding: true,
        workspaceName: workspaceName,
        workspaceFocus: workspaceFocus,
        wantsNotifications: wantsNotifications,
        themePreference: themePreference,
      ),
    );
  }
}

class _FakeNotesController extends NotesController {
  _FakeNotesController(this.notesState);

  final NotesState notesState;

  @override
  Future<NotesState> build() async => notesState;
}

class _FakeAuthController extends AuthController {
  String? passwordResetEmail;
  String? signUpEmail;
  String? signUpPassword;
  String? signUpDisplayName;

  @override
  FutureOr<void> build() {}

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    passwordResetEmail = email;
    state = const AsyncData<void>(null);
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    signUpEmail = email;
    signUpPassword = password;
    signUpDisplayName = displayName;
    state = const AsyncData<void>(null);
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncData<void>(null);
  }
}