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
import '../providers/providers.dart';
import '../shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/room',
    redirect: (context, state) {
      final isAuth = authState.valueOrNull != null;
      final hasCoupleId = userState.valueOrNull?.coupleId != null;
      final isLoading = authState.isLoading || userState.isLoading;

      if (isLoading) return null;

      final onAuth = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation.startsWith('/pair') ||
          state.matchedLocation.startsWith('/onboarding');

      if (!isAuth) return onAuth ? null : '/auth';
      if (isAuth && !hasCoupleId) return onAuth ? null : '/pair';
      if (onAuth) return '/room';
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/pair', builder: (_, __) => const PairingScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/room', builder: (_, __) => const RoomScreen()),
          GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
          GoRoute(path: '/memory', builder: (_, __) => const MemoryWallScreen()),
          GoRoute(
            path: '/memory/:id',
            builder: (_, state) =>
                MemoryDetailScreen(memoryId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/together', builder: (_, __) => const TogetherScreen()),
          GoRoute(
            path: '/together/letter/new',
            builder: (_, __) => const LetterComposeScreen(),
          ),
          GoRoute(
            path: '/together/journal',
            builder: (_, __) => const JournalScreen(),
          ),
          GoRoute(path: '/you', builder: (_, __) => const YouAndMeScreen()),
        ],
      ),
    ],
  );
});
