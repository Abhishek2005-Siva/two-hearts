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
import '../../features/games/date_ideas_screen.dart';
import '../../features/chat/snaps_screen.dart';
import '../../features/memory/photo_booth_screen.dart';
import '../../features/together/bucket_list_screen.dart';
import '../../features/avatar/avatar_creator_screen.dart';
import '../../features/places/places_screen.dart';
import '../../features/books/book_wishlist_screen.dart';
import '../../features/cinema/cinema_screen.dart';
import '../firebase/models.dart';
import '../providers/providers.dart';
import '../shell/main_shell.dart';

// Notifier that fires whenever auth or couple state changes so GoRouter
// re-evaluates its redirect without recreating the router instance.
class _RouterNotifier extends ChangeNotifier {
  bool _isPaired = false;
  // Stays false until coupleProvider emits its first non-loading value.
  // While false we suppress the /pair redirect to avoid a flash on auto sign-in.
  bool _coupleLoaded = false;

  _RouterNotifier(Ref ref) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      // Reset loaded flag when the auth user changes so we wait for fresh data.
      if (user == null) {
        _coupleLoaded = false;
        _isPaired = false;
      }
      notifyListeners();
    });
    ref.listen<AsyncValue<CoupleModel?>>(coupleProvider, (_, next) {
      if (next is AsyncLoading) return; // still fetching — don't decide yet
      _coupleLoaded = true;
      // Paired = the couple actually has BOTH members. Having a partner is
      // mandatory — generating a code alone keeps you on the pairing screen
      // until your person joins.
      final couple = next.valueOrNull;
      final paired = couple != null && couple.members.length >= 2;
      if (paired != _isPaired) {
        _isPaired = paired;
      }
      notifyListeners();
    });
  }

  bool get isPaired => _isPaired;
  bool get coupleLoaded => _coupleLoaded;
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
      final coupleLoaded = notifier.coupleLoaded;

      final onAuth = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation.startsWith('/pair') ||
          state.matchedLocation.startsWith('/onboarding');

      // Not signed in → force to auth.
      if (!isAuth) return onAuth ? null : '/auth';

      // Signed in but Firestore hasn't confirmed couple status yet — wait.
      if (!coupleLoaded) return null;

      // Pairing is mandatory: a signed-in user without a partner can only
      // be on /pair (or /onboarding) until they generate or enter a code.
      if (!isPaired) {
        final onPairFlow = state.matchedLocation.startsWith('/pair') ||
            state.matchedLocation.startsWith('/onboarding');
        return onPairFlow ? null : '/pair';
      }

      // Once pairing is complete, bounce away from auth/pair screens.
      if (isPaired && onAuth) return '/room';
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
      // Fullscreen — outside the shell so the bottom nav never overlaps the movie.
      GoRoute(path: '/cinema', builder: (_, _) => const CinemaScreen()),
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
          GoRoute(path: '/dates', builder: (_, _) => const DateIdeasScreen()),
          GoRoute(path: '/snaps', builder: (_, _) => const SnapsScreen()),
          GoRoute(path: '/photo_booth', builder: (_, _) => const PhotoBoothScreen()),
          GoRoute(path: '/together/bucket', builder: (_, _) => const BucketListScreen()),
          GoRoute(path: '/avatar-creator', builder: (_, _) => const AvatarCreatorScreen()),
          GoRoute(path: '/places', builder: (_, _) => const PlacesScreen()),
          GoRoute(path: '/books', builder: (_, _) => const BookWishlistScreen()),
        ],
      ),
    ],
  );
});
