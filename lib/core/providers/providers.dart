import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase/firestore_service.dart';
import '../firebase/models.dart';

// ── Firebase Auth ─────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ── FirestoreService singleton ────────────────────────────────────────────

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// ── Current User (Firestore doc) ──────────────────────────────────────────

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchUser(auth.uid);
});

// ── Couple ────────────────────────────────────────────────────────────────

final coupleIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.coupleId;
});

final coupleProvider = StreamProvider<CoupleModel?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  // While user doc is loading, keep the provider in AsyncLoading
  if (userAsync is AsyncLoading) return const Stream.empty();
  final coupleId = ref.watch(coupleIdProvider);
  // User doc loaded but no coupleId → emit null so router knows they're unpaired
  if (coupleId == null) return Stream.value(null);
  return ref.read(firestoreServiceProvider).watchCouple(coupleId);
});

// ── Accent color (driven by couple theme) ────────────────────────────────

final accentColorProvider = Provider<Color>((ref) {
  final couple = ref.watch(coupleProvider).valueOrNull;
  if (couple == null) return const Color(0xFFE8896A);
  return Color(couple.themeColor);
});

// ── Messages ──────────────────────────────────────────────────────────────

final messagesProvider = StreamProvider<List<MessageModel>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchMessages(coupleId);
});

final snapsProvider = StreamProvider<List<MessageModel>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchSnaps(coupleId);
});

final chatImagesProvider = StreamProvider<List<MessageModel>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchImageMessages(coupleId);
});

// ── Moods ─────────────────────────────────────────────────────────────────

final moodsProvider = StreamProvider<List<MoodEntry>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchMoods(coupleId);
});

// ── Letters (receiver-only, unlocked-only) ────────────────────────────────

final lettersProvider = StreamProvider<List<LetterModel>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  final myUid = ref.watch(currentUserProvider).valueOrNull?.uid;
  if (coupleId == null || myUid == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchLetters(coupleId, myUid);
});

final sentLettersProvider = StreamProvider<List<LetterModel>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  final myUid = ref.watch(currentUserProvider).valueOrNull?.uid;
  if (coupleId == null || myUid == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchSentLetters(coupleId, myUid);
});

// ── Journal ───────────────────────────────────────────────────────────────

final journalProvider = StreamProvider<List<JournalDay>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchJournal(coupleId);
});

// ── Memories ──────────────────────────────────────────────────────────────

final memoriesProvider = StreamProvider<List<MemoryModel>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchMemories(coupleId);
});

// ── Photo Collections ─────────────────────────────────────────────────────

final photoCollectionsProvider = StreamProvider<List<PhotoCollection>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchCollections(coupleId);
});

// ── Bucket List ───────────────────────────────────────────────────────────

final bucketListProvider = StreamProvider<List<BucketItem>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchBucketList(coupleId);
});

// ── Room Objects ──────────────────────────────────────────────────────────

final roomObjectsProvider = StreamProvider<List<RoomObject>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchRoomObjects(coupleId);
});

// ── Home Decor (isometric shared room) ────────────────────────────────────

final homeDecorProvider = StreamProvider<List<Furniture3DItem>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchHomeDecor(coupleId);
});

final homeRoomStyleProvider = StreamProvider<HomeRoomStyle>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return Stream.value(const HomeRoomStyle());
  return ref.read(firestoreServiceProvider).watchHomeRoomStyle(coupleId);
});

final houseLayoutProvider = StreamProvider<HouseLayout>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return Stream.value(const HouseLayout());
  return ref.read(firestoreServiceProvider).watchHouseLayout(coupleId);
});

final homeWidgetDrawingProvider = StreamProvider<HomeWidgetDrawing>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return Stream.value(const HomeWidgetDrawing());
  return ref.read(firestoreServiceProvider).watchHomeWidgetDrawing(coupleId);
});

final dailySnapsProvider = StreamProvider<List<DailySnap>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchDailySnaps(coupleId);
});

final dailySnapReactionsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, dateKey) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchDailySnapReactions(coupleId, dateKey);
});

final dailySnapCommentsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, dateKey) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchDailySnapComments(coupleId, dateKey);
});

// ── Wildcards ──────────────────────────────────────────────────────────────

final wildcardsProvider = StreamProvider<List<WildCard>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchWildcards(coupleId);
});

final wildcardRequestsProvider = StreamProvider<List<WildcardRequest>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchWildcardRequests(coupleId);
});

// ── Partner User ──────────────────────────────────────────────────────────

final partnerUserProvider = StreamProvider<UserModel?>((ref) {
  final couple = ref.watch(coupleProvider).valueOrNull;
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (couple == null || me == null) return const Stream.empty();
  final partnerUid = couple.partnerUid(me.uid);
  if (partnerUid.isEmpty) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchUser(partnerUid);
});

// ── Partner Online ────────────────────────────────────────────────────────

final partnerOnlineProvider = StreamProvider<bool>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  final couple = ref.watch(coupleProvider).valueOrNull;
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (coupleId == null || couple == null || me == null) return Stream.value(false);
  final partnerUid = couple.partnerUid(me.uid);
  if (partnerUid.isEmpty) return Stream.value(false);
  return ref.read(firestoreServiceProvider).watchPartnerOnline(coupleId, partnerUid);
});

// ── Partner Section (which tab they're in right now) ─────────────────────

final partnerSectionProvider = StreamProvider<String?>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  final couple = ref.watch(coupleProvider).valueOrNull;
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (coupleId == null || couple == null || me == null) {
    return Stream.value(null);
  }
  final partnerUid = couple.partnerUid(me.uid);
  if (partnerUid.isEmpty) return Stream.value(null);
  return ref
      .read(firestoreServiceProvider)
      .watchPartnerSection(coupleId, partnerUid);
});

// ── Partner Activity (finer-grained than section — "Reading X", etc.) ────

final partnerActivityLabelProvider = StreamProvider<String?>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  final couple = ref.watch(coupleProvider).valueOrNull;
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (coupleId == null || couple == null || me == null) {
    return Stream.value(null);
  }
  final partnerUid = couple.partnerUid(me.uid);
  if (partnerUid.isEmpty) return Stream.value(null);
  return ref
      .read(firestoreServiceProvider)
      .watchPartnerActivityLabel(coupleId, partnerUid);
});

// ── Unread chat messages (for the Chat tab badge) ─────────────────────────

final unreadChatCountProvider = Provider<int>((ref) {
  final me = ref.watch(currentUserProvider).valueOrNull;
  final messages = ref.watch(messagesProvider).valueOrNull;
  if (me == null || messages == null) return 0;
  return messages
      .where((m) => m.senderId != me.uid && !m.readByPartner)
      .length;
});

// ── Notifications (shared activity feed) ──────────────────────────────────

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchNotifications(coupleId);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final me = ref.watch(currentUserProvider).valueOrNull;
  final notifications = ref.watch(notificationsProvider).valueOrNull;
  if (me == null || notifications == null) return 0;
  return notifications.where((n) => n.isUnreadFor(me.uid)).length;
});

// ── Incoming Gift (wild idea present box) ─────────────────────────────────

final incomingGiftProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (coupleId == null || me == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('couples')
      .doc(coupleId)
      .collection('signals')
      .where('type', isEqualTo: 'gift')
      .where('toUid', isEqualTo: me.uid)
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.isEmpty
          ? null
          : {'id': snap.docs.first.id, ...snap.docs.first.data()});
});

// ── Today's Game (Would You Rather) ──────────────────────────────────────

final todayGameProvider = StreamProvider<GameRound?>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchTodayGame(coupleId);
});

// ── Partner typing indicator ──────────────────────────────────────────────

final partnerTypingProvider = StreamProvider<bool>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  final couple = ref.watch(coupleProvider).valueOrNull;
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (coupleId == null || couple == null || me == null) return Stream.value(false);
  final partnerUid = couple.partnerUid(me.uid);
  if (partnerUid.isEmpty) return Stream.value(false);
  return ref.read(firestoreServiceProvider).watchPartnerTyping(coupleId, partnerUid);
});

// ── Partner activity status (recording / uploading) & last seen ──────────

final partnerActivityStatusProvider = StreamProvider<String?>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  final couple = ref.watch(coupleProvider).valueOrNull;
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (coupleId == null || couple == null || me == null) return Stream.value(null);
  final partnerUid = couple.partnerUid(me.uid);
  if (partnerUid.isEmpty) return Stream.value(null);
  return ref.read(firestoreServiceProvider).watchPartnerActivityStatus(coupleId, partnerUid);
});

final partnerLastSeenProvider = StreamProvider<DateTime?>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  final couple = ref.watch(coupleProvider).valueOrNull;
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (coupleId == null || couple == null || me == null) return Stream.value(null);
  final partnerUid = couple.partnerUid(me.uid);
  if (partnerUid.isEmpty) return Stream.value(null);
  return ref.read(firestoreServiceProvider).watchPartnerLastSeen(coupleId, partnerUid);
});

// ── Shared Note ────────────────────────────────────────────────────────────

final sharedNoteProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return Stream.value(null);
  return ref.read(firestoreServiceProvider).watchSharedNote(coupleId);
});

// ── Today's Truths (Truth Jar) ────────────────────────────────────────────

final todayTruthsProvider = StreamProvider<Map<String, String>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return Stream.value({});
  return ref.read(firestoreServiceProvider).watchTodayTruths(coupleId);
});

// ── Date Wheel result ─────────────────────────────────────────────────────

final dateWheelProvider = StreamProvider<int?>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return Stream.value(null);
  return ref.read(firestoreServiceProvider).watchDateWheelResult(coupleId);
});

// ── Compatibility stats ───────────────────────────────────────────────────

final compatibilityStatsProvider = FutureProvider<Map<String, int>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return Future.value({'total': 0, 'matched': 0});
  return ref.read(firestoreServiceProvider).getCompatibilityStats(coupleId);
});

// ── Places ────────────────────────────────────────────────────────────────

final placesProvider = StreamProvider<List<PlacePin>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchPlaces(coupleId);
});

// ── Books ─────────────────────────────────────────────────────────────────

final booksProvider = StreamProvider<List<BookWish>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchBooks(coupleId);
});

final recipesProvider = StreamProvider<List<RecipeModel>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchRecipes(coupleId);
});

// ── Incoming Video Call ───────────────────────────────────────────────────

final incomingCallProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (coupleId == null || me == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('couples')
      .doc(coupleId)
      .collection('calls')
      .where('status', isEqualTo: 'ringing')
      .snapshots()
      .map((snap) {
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['callerId'] != me.uid) {
        final created = (data['createdAt'] as Timestamp?)?.toDate();
        // Ignore calls older than 60 seconds (stale)
        if (created != null &&
            DateTime.now().difference(created).inSeconds > 60) {
          continue;
        }
        return {'id': doc.id, ...data};
      }
    }
    return null;
  });
});

// ── Cinema (Watch Together) ──────────────────────────────────────────────

final cinemaSessionProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return Stream.value(null);
  return ref.read(firestoreServiceProvider).watchCinemaSession(coupleId);
});

// ── Listen Together (Spotify) ────────────────────────────────────────────

final listenSessionProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return Stream.value(null);
  return ref.read(firestoreServiceProvider).watchListenSession(coupleId);
});

// ── Theme Mode (persisted across restarts) ───────────────────────────────

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _prefsKey = 'theme_mode';

  @override
  ThemeMode build() {
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString(_prefsKey);
      if (saved == 'light') state = ThemeMode.light;
    });
    return ThemeMode.dark;
  }

  void set(ThemeMode mode) {
    state = mode;
    SharedPreferences.getInstance().then((prefs) =>
        prefs.setString(_prefsKey, mode == ThemeMode.light ? 'light' : 'dark'));
  }
}

// ── Scribble ─────────────────────────────────────────────────────────────

final scribbleProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return Stream.value(null);
  return ref.read(firestoreServiceProvider).watchScribble(coupleId);
});
