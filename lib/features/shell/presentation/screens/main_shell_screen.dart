import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_env.dart';
import '../../../../shared/widgets/responsive_centered_shell.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../auth/auth_providers.dart';
import '../../../folders/presentation/screens/folders_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../../sync/presentation/controllers/sync_controller.dart';
import '../controllers/shell_controller.dart';
import '../widgets/main_bottom_nav.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with WidgetsBindingObserver {
  static const Duration _syncRefreshInterval = Duration(minutes: 3);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  bool _didScheduleInitialSyncBootstrap = false;
  List<ConnectivityResult> _lastConnectivityResults =
      const <ConnectivityResult>[ConnectivityResult.none];
  String? _lastBootstrappedSyncUserId;

  @override
  void initState() {
    super.initState();

    if (!AppEnv.enableExperimentalSync) {
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    _startConnectivityListener();
    _startPeriodicSyncTimer();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();

    if (AppEnv.enableExperimentalSync) {
      WidgetsBinding.instance.removeObserver(this);
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerSyncIfAuthenticated();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AppEnv.enableExperimentalSync) {
      ref.listen(currentAuthSessionProvider, (previous, next) {
        if (next == null) {
          _lastBootstrappedSyncUserId = null;
          return;
        }

        if (previous?.uid == next.uid &&
            _lastBootstrappedSyncUserId == next.uid) {
          return;
        }

        _lastBootstrappedSyncUserId = next.uid;
        unawaited(
          ref
              .read(syncControllerProvider.notifier)
              .syncNow(forceFullPull: true),
        );
      });

      if (!_didScheduleInitialSyncBootstrap) {
        _didScheduleInitialSyncBootstrap = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          final session = ref.read(currentAuthSessionProvider);
          if (session == null || _lastBootstrappedSyncUserId == session.uid) {
            return;
          }

          _lastBootstrappedSyncUserId = session.uid;
          _triggerSyncIfAuthenticated(forceFullPull: true);
        });
      }
    }

    final activeTab = ref.watch(shellTabProvider);
    final palette = context.palette;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        if (activeTab != ShellTab.home) {
          ref.read(shellTabProvider.notifier).state = ShellTab.home;
          return;
        }

        if (Theme.of(context).platform == TargetPlatform.android) {
          SystemNavigator.pop();
        }
      },
      child: ResponsiveCenteredShell(
        usePresentationFrame: true,
        child: Scaffold(
          backgroundColor: palette.pageBackground,
          body: Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(
                  index: activeTab.index,
                  children: const [
                    HomeScreen(),
                    SearchScreen(),
                    FoldersScreen(),
                    ProfileScreen(),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MainBottomNav(
                  activeTab: activeTab,
                  onTabSelected: (tab) =>
                      ref.read(shellTabProvider.notifier).state = tab,
                  onCreateTap: () {
                    context.push(RouteNames.editor);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startPeriodicSyncTimer() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(_syncRefreshInterval, (_) {
      if (!mounted) {
        return;
      }

      _triggerSyncIfAuthenticated();
    });
  }

  void _startConnectivityListener() {
    final connectivity = Connectivity();

    unawaited(() async {
      _lastConnectivityResults = await connectivity.checkConnectivity();
    }());

    _connectivitySubscription?.cancel();
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      (results) {
        final wasOffline = _isOffline(_lastConnectivityResults);
        final isOffline = _isOffline(results);
        _lastConnectivityResults =
            List<ConnectivityResult>.unmodifiable(results);

        if (wasOffline && !isOffline) {
          _triggerSyncIfAuthenticated();
        }
      },
    );
  }

  bool _isOffline(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      return true;
    }

    return results.every((result) => result == ConnectivityResult.none);
  }

  void _triggerSyncIfAuthenticated({bool forceFullPull = false}) {
    if (!AppEnv.enableExperimentalSync) {
      return;
    }

    final session = ref.read(currentAuthSessionProvider);
    if (session == null) {
      return;
    }

    unawaited(
      ref.read(syncControllerProvider.notifier).syncNow(
            forceFullPull: forceFullPull,
          ),
    );
  }
}
