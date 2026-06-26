import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/auth/pairing_screen.dart';
import '../../features/auth/onboarding_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/room/room_screen.dart';
import '../../features/memory/memory_wall_screen.dart';
import '../../features/together/together_screen.dart';
import '../../features/you_and_me/you_and_me_screen.dart';
import '../../features/together/letter_compose_screen.dart';
import '../../features/together/journal_screen.dart';
import '../../features/memory/memory_detail_screen.dart';
import '../../features/games/games_screen.dart';
import '../firebase/models.dart';
import '../providers/providers.dart';
import '../shell/main_shell.dart';

// Notifier that fires whenever auth or couple state changes so GoRouter
// re-evaluates its redirect without recreating the router instance.
class _RouterNotifier extends ChangeNotifier {
  bool _isPaired = false; // true only when couple.members.length >= 2

  _RouterNotifier(Ref ref) {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
    ref.listen<AsyncValue<CoupleModel?>>(coupleProvider, (_, next) {
      final paired = (next.valueOrNull?.members.length ?? 0) >= 2;
      if (paired != _isPaired) {
        _isPaired = paired;
        notifyListeners();
      }
    });
  }

  bool get isPaired => _isPaired;
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(_routerNotifierProvider);

  return GoRouter(
    initialLocation: '/room',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isAuth = FirebaseAuth.instance.currentUser != null;
      final isPaired = notifier.isPaired;

      final onAuth = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation.startsWith('/pair') ||
          state.matchedLocation.startsWith('/onboarding');

      if (!isAuth) return onAuth ? null : '/auth';
      if (isAuth && !isPaired) return onAuth ? null : '/pair';
      if (onAuth) return '/room';
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: '/pair',
        builder: (_, state) => PairingScreen(
          initialCode: state.uri.queryParameters['code'],
        ),
      ),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/room', builder: (_, _) => const RoomScreen()),
          GoRoute(path: '/chat', builder: (_, _) => const ChatScreen()),
          GoRoute(path: '/memory', builder: (_, _) => const MemoryWallScreen()),
          GoRoute(
            path: '/memory/:id',
            builder: (_, state) =>
                MemoryDetailScreen(memoryId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/together', builder: (_, _) => const TogetherScreen()),
          GoRoute(
            path: '/together/letter/new',
            builder: (_, _) => const LetterComposeScreen(),
          ),
          GoRoute(
            path: '/together/journal',
            builder: (_, _) => const JournalScreen(),
          ),
          GoRoute(path: '/you', builder: (_, _) => const YouAndMeScreen()),
          GoRoute(path: '/games', builder: (_, _) => const GamesScreen()),
        ],
      ),
    ],
  );
});
