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
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
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

// ── Moods ─────────────────────────────────────────────────────────────────

final moodsProvider = StreamProvider<List<MoodEntry>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchMoods(coupleId);
});

// ── Letters ───────────────────────────────────────────────────────────────

final lettersProvider = StreamProvider<List<LetterModel>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return const Stream.empty();
  return ref.read(firestoreServiceProvider).watchLetters(coupleId);
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
