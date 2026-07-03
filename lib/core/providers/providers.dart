import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// ── Theme Mode ───────────────────────────────────────────────────────────

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

// ── Scribble ─────────────────────────────────────────────────────────────

final scribbleProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return Stream.value(null);
  return ref.read(firestoreServiceProvider).watchScribble(coupleId);
});
