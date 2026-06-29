import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fcm_service.dart';
import 'models.dart';
import '../../features/avatar/avatar_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('FirestoreService called without authenticated user');
    return uid;
  }

  // ── User ──────────────────────────────────────────────────────────────────

  Future<void> createUser(UserModel user) =>
      _db.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  Stream<UserModel?> watchUser(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? UserModel.fromDoc(d) : null);

  Future<void> updateUser(Map<String, dynamic> data) =>
      _db.collection('users').doc(_uid).update(data);

  Future<void> updateBirthday(DateTime birthday) =>
      _db.collection('users').doc(_uid).update({
        'birthday': Timestamp.fromDate(birthday),
      });

  // ── Couple / Pairing ──────────────────────────────────────────────────────

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<String> createInviteCode() async {
    final code = _generateInviteCode();
    final coupleRef = _db.collection('couples').doc();
    await coupleRef.set({
      'members': [_uid],
      'themeColor': 0xFFE8896A,
      'createdAt': FieldValue.serverTimestamp(),
      'inviteCode': code,
    });
    await _db.collection('users').doc(_uid).update({'coupleId': coupleRef.id});
    return code;
  }

  Future<CoupleModel?> redeemInviteCode(String code) async {
    final snap = await _db
        .collection('couples')
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final coupleDoc = snap.docs.first;
    final couple = CoupleModel.fromDoc(coupleDoc);

    if (couple.members.length >= 2) return null;
    if (couple.members.contains(_uid)) return null;

    await coupleDoc.reference.update({
      'members': FieldValue.arrayUnion([_uid]),
      'inviteCode': FieldValue.delete(),
    });
    await _db.collection('users').doc(_uid).update({'coupleId': coupleDoc.id});

    final updated = await coupleDoc.reference.get();
    return CoupleModel.fromDoc(updated);
  }

  Stream<CoupleModel?> watchCouple(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .snapshots()
      .map((d) => d.exists ? CoupleModel.fromDoc(d) : null);

  Future<void> updateCoupleTheme(String coupleId, int colorValue) =>
      _db.collection('couples').doc(coupleId).update({'themeColor': colorValue});

  Future<void> setChatBackground(String coupleId, String backgroundName,
          {String? customUrl}) =>
      _db.collection('couples').doc(coupleId).update({
        'chatBackground': backgroundName,
        if (customUrl != null) 'chatBackgroundUrl': customUrl,
        if (customUrl == null) 'chatBackgroundUrl': FieldValue.delete(),
      });

  // ── Presence ──────────────────────────────────────────────────────────────

  Future<void> setPresence(String coupleId) => _db
      .collection('couples').doc(coupleId)
      .update({'presence.$_uid': FieldValue.serverTimestamp()});

  Stream<bool> watchPartnerOnline(String coupleId, String partnerUid) => _db
      .collection('couples').doc(coupleId).snapshots()
      .map((d) {
        final ts = d.data()?['presence']?[partnerUid];
        if (ts == null) return false;
        return DateTime.now().difference((ts as Timestamp).toDate()).inMinutes < 5;
      });

  // ── Messages ──────────────────────────────────────────────────────────────

  Stream<List<MessageModel>> watchMessages(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .orderBy('sentAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(MessageModel.fromDoc).toList());

  Stream<List<MessageModel>> watchSnaps(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .where('isSnap', isEqualTo: true)
      .snapshots()
      .map((s) {
        final list = s.docs.map(MessageModel.fromDoc).toList();
        list.sort((a, b) => b.sentAt.compareTo(a.sentAt));
        return list;
      });

  Stream<List<MessageModel>> watchImageMessages(String coupleId) =>
      watchMessages(coupleId).map(
          (msgs) => msgs.where((m) => m.type == MessageType.image).toList());

  // ── FCM helpers ───────────────────────────────────────────────────────────

  Future<String?> _partnerToken(String coupleId) async {
    final couple = await _db.collection('couples').doc(coupleId).get();
    if (!couple.exists) return null;
    final members = List<String>.from(couple.data()?['members'] ?? []);
    final partnerUid = members.firstWhere((id) => id != _uid, orElse: () => '');
    if (partnerUid.isEmpty) return null;
    final userDoc = await _db.collection('users').doc(partnerUid).get();
    return userDoc.data()?['fcmToken'] as String?;
  }

  Future<String> _myFirstName() async {
    final doc = await _db.collection('users').doc(_uid).get();
    final full = (doc.data()?['displayName'] as String?) ?? 'Your partner';
    return full.split(' ').first;
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<void> sendMessage(String coupleId, MessageModel msg) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('messages')
        .doc(msg.id)
        .set(msg.toMap());
    if (msg.isSnap) return; // snaps are ephemeral, skip notification
    final token = await _partnerToken(coupleId);
    final name = await _myFirstName();
    final body = switch (msg.type) {
      MessageType.image => '$name sent a photo 📷',
      MessageType.video => '$name sent a video 🎥',
      _ => msg.content.isNotEmpty ? msg.content : '$name sent a message',
    };
    await FcmService.send(
      recipientToken: token,
      title: name,
      body: body,
      data: {'type': 'message', 'coupleId': coupleId, 'route': '/chat'},
    );
  }

  Future<void> markMessageRead(String coupleId, String msgId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .doc(msgId)
      .update({'readByPartner': true});

  Future<void> markMessagesRead(String coupleId, List<String> msgIds) async {
    final batch = _db.batch();
    for (final id in msgIds) {
      batch.update(_db.collection('couples').doc(coupleId).collection('messages').doc(id),
          {'readByPartner': true});
    }
    await batch.commit();
  }

  Future<void> reactToMessage(String coupleId, String msgId, String emoji) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .doc(msgId)
      .update({
        'reactionEmoji': emoji.isEmpty ? FieldValue.delete() : emoji,
      });

  Future<void> deleteMessage(String coupleId, String msgId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .doc(msgId)
      .delete();

  Future<void> viewSnap(String coupleId, String msgId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('messages')
      .doc(msgId)
      .update({'snapViewed': true});

  // ── Mood ──────────────────────────────────────────────────────────────────

  Future<void> setMood(String coupleId, MoodType mood) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('moods')
        .doc(_uid)
        .set(MoodEntry(uid: _uid, mood: mood, updatedAt: DateTime.now()).toMap());
    final token = await _partnerToken(coupleId);
    final name = await _myFirstName();
    final emoji = mood.emoji;
    final moodName = mood.name;
    await FcmService.send(
      recipientToken: token,
      title: '$name is feeling $moodName $emoji',
      body: 'Check in on them ♡',
      data: {'type': 'mood', 'coupleId': coupleId, 'route': '/room'},
    );
  }

  Stream<List<MoodEntry>> watchMoods(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('moods')
      .snapshots()
      .map((s) => s.docs.map(MoodEntry.fromDoc).toList());

  // ── Thinking Of You ───────────────────────────────────────────────────────

  Future<void> sendThinkingOfYou(String coupleId,
      {String? message, String? toUid}) async {
    await _db.collection('couples').doc(coupleId).collection('signals').add({
      'type': 'thinkingOfYou',
      'fromUid': _uid,
      if (toUid != null) 'toUid': toUid,
      if (message != null) 'message': message,
      'sentAt': FieldValue.serverTimestamp(),
    });
    final token = toUid != null
        ? ((await _db.collection('users').doc(toUid).get()).data()?['fcmToken'] as String?)
        : await _partnerToken(coupleId);
    final name = await _myFirstName();
    await FcmService.send(
      recipientToken: token,
      title: '♡ $name is thinking of you',
      body: message ?? 'A little love from your person ♡',
      data: {'type': 'signal', 'coupleId': coupleId, 'route': '/room'},
    );
  }

  Stream<QuerySnapshot> watchSignals(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('signals')
      .orderBy('sentAt', descending: true)
      .limit(1)
      .snapshots();

  Future<void> deleteSignal(String coupleId, String signalId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('signals')
      .doc(signalId)
      .delete();

  Future<void> sendSignal(String coupleId, String type, {String? message}) async {
    await _db.collection('couples').doc(coupleId).collection('signals').add({
      'type': type,
      'fromUid': _uid,
      if (message != null) 'message': message,
      'sentAt': FieldValue.serverTimestamp(),
    });
    final token = await _partnerToken(coupleId);
    final name = await _myFirstName();
    final (title, body) = switch (type) {
      'goodMorning' => ('☀️ Good morning from $name', 'They wished you a beautiful morning ♡'),
      'goodNight'   => ('🌙 Good night from $name', 'Sweet dreams — they\'re thinking of you ♡'),
      'gratitude'   => ('🙏 $name is grateful for you', 'They wanted you to know ♡'),
      _             => ('♡ $name is thinking of you', message ?? 'A little love from your person ♡'),
    };
    await FcmService.send(
      recipientToken: token,
      title: title,
      body: body,
      data: {'type': 'signal', 'signalType': type, 'coupleId': coupleId, 'route': '/room'},
    );
  }

  // ── Letters ───────────────────────────────────────────────────────────────

  Future<void> sendLetter(String coupleId, LetterModel letter) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('letters')
      .doc(letter.id)
      .set(letter.toMap());

  // Returns only letters the current user received (not authored) that are unlocked.
  // Locked letters are completely hidden from the receiver.
  Stream<List<LetterModel>> watchLetters(String coupleId, String myUid) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('letters')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(LetterModel.fromDoc).toList().where((l) {
            // Show only letters where I'm the recipient (not the author)
            final isReceiver = l.receiverId == myUid ||
                (l.receiverId == null && l.authorId != myUid);
            // Only show unlocked letters (locked ones are invisible to receiver)
            return isReceiver && l.isUnlocked;
          }).toList());

  Future<void> openLetter(String coupleId, String letterId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('letters')
      .doc(letterId)
      .update({'opened': true});

  // ── Journal ───────────────────────────────────────────────────────────────

  Future<void> submitJournalEntry(
      String coupleId, String dayId, String entry, String otherUid,
      {String? title}) async {
    final ref = _db
        .collection('couples')
        .doc(coupleId)
        .collection('journal')
        .doc(dayId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'uidA': _uid,
        'entryA': entry,
        'uidB': null,
        'entryB': null,
        'bothSubmitted': false,
        if (title != null) 'title': title,
      });
    } else {
      final d = doc.data() as Map<String, dynamic>;
      final isA = d['uidA'] == _uid;
      final otherField = isA ? 'entryB' : 'entryA';
      final otherUidField = isA ? 'uidB' : 'uidA';
      final myField = isA ? 'entryA' : 'entryB';
      final otherAlreadyIn = d[otherField] != null;
      await ref.update({
        myField: entry,
        otherUidField: otherUid,
        'bothSubmitted': otherAlreadyIn,
        if (title != null && d['title'] == null) 'title': title,
      });
    }
  }

  Future<void> saveJournalEntry(String coupleId, String dayId, String content,
      {String? title}) =>
      _db
          .collection('couples')
          .doc(coupleId)
          .collection('journal')
          .doc(dayId)
          .set({
        'sharedEntry': content,
        'title': title ?? '',
        'lastEditedBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Stream<List<JournalDay>> watchJournal(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('journal')
      .snapshots()
      .map((s) {
        final list = s.docs.map(JournalDay.fromDoc).toList();
        list.sort((a, b) => b.id.compareTo(a.id));
        return list;
      });

  // ── Memories ──────────────────────────────────────────────────────────────

  Future<void> addMemory(String coupleId, MemoryModel memory) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('memories')
        .doc(memory.id)
        .set(memory.toMap());
    await _addRoomObject(coupleId, RoomObject(
      id: 'frame_${memory.id}',
      type: RoomObjectType.photoFrame,
      sourceRef: memory.id,
      position: {'x': _randomPos(), 'y': 0.0, 'z': _randomPos()},
      createdAt: DateTime.now(),
    ));
    // Update collection cover/count
    if (memory.collectionId != null) {
      await _db
          .collection('couples').doc(coupleId)
          .collection('photoCollections').doc(memory.collectionId)
          .update({
            'photoCount': FieldValue.increment(1),
            'coverUrl': memory.imageUrl,
          });
    }
  }

  Future<void> assignToCollection(String coupleId, String memoryId, String? collectionId) => _db
      .collection('couples').doc(coupleId).collection('memories').doc(memoryId)
      .update({'collectionId': collectionId});

  Stream<List<MemoryModel>> watchMemories(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('memories')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MemoryModel.fromDoc).toList());

  Stream<List<MemoryModel>> watchCollectionMemories(String coupleId, String collectionId) => _db
      .collection('couples').doc(coupleId).collection('memories')
      .where('collectionId', isEqualTo: collectionId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(MemoryModel.fromDoc).toList());

  Future<void> toggleFavoriteMemory(String coupleId, String memoryId, bool fav) =>
      _db.collection('couples').doc(coupleId).collection('memories').doc(memoryId)
          .update({'favorite': fav});

  Future<void> requestMemoryDeletion(String coupleId, String memoryId) =>
      _db.collection('couples').doc(coupleId).collection('memories').doc(memoryId)
          .update({'deletionRequestedBy': _uid});

  Future<void> cancelMemoryDeletion(String coupleId, String memoryId) =>
      _db.collection('couples').doc(coupleId).collection('memories').doc(memoryId)
          .update({'deletionRequestedBy': FieldValue.delete()});

  Future<void> approveMemoryDeletion(String coupleId, String memoryId) =>
      _db.collection('couples').doc(coupleId).collection('memories').doc(memoryId).delete();

  // ── Photo Collections ─────────────────────────────────────────────────────

  Future<PhotoCollection> createCollection(String coupleId, String name) async {
    final ref = _db.collection('couples').doc(coupleId).collection('photoCollections').doc();
    final col = PhotoCollection(
      id: ref.id,
      name: name,
      createdBy: _uid,
      createdAt: DateTime.now(),
    );
    await ref.set(col.toMap());
    return col;
  }

  Stream<List<PhotoCollection>> watchCollections(String coupleId) => _db
      .collection('couples').doc(coupleId).collection('photoCollections')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(PhotoCollection.fromDoc).toList());

  Future<void> deleteCollection(String coupleId, String collectionId) async {
    // Unassign photos from the collection
    final memories = await _db
        .collection('couples').doc(coupleId).collection('memories')
        .where('collectionId', isEqualTo: collectionId).get();
    final batch = _db.batch();
    for (final doc in memories.docs) {
      batch.update(doc.reference, {'collectionId': FieldValue.delete()});
    }
    batch.delete(_db.collection('couples').doc(coupleId)
        .collection('photoCollections').doc(collectionId));
    await batch.commit();
  }

  // ── Bucket List ───────────────────────────────────────────────────────────

  Future<void> addBucketItem(String coupleId, BucketItem item) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('bucketList')
      .doc(item.id)
      .set(item.toMap());

  Stream<List<BucketItem>> watchBucketList(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('bucketList')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(BucketItem.fromDoc).toList());

  Future<void> deleteBucketItem(String coupleId, String itemId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('bucketList')
      .doc(itemId)
      .delete();

  Future<void> updateBucketStatus(
      String coupleId, String itemId, BucketStatus status) async {
    await _db
        .collection('couples')
        .doc(coupleId)
        .collection('bucketList')
        .doc(itemId)
        .update({'status': status.name});
    if (status == BucketStatus.done) {
      await _addRoomObject(coupleId, RoomObject(
        id: 'trophy_$itemId',
        type: RoomObjectType.bucketTrophy,
        sourceRef: itemId,
        position: {'x': _randomPos(), 'y': 0.0, 'z': _randomPos()},
        createdAt: DateTime.now(),
      ));
    }
  }

  // ── Room Objects ──────────────────────────────────────────────────────────

  Future<void> _addRoomObject(String coupleId, RoomObject obj) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('roomObjects')
      .doc(obj.id)
      .set(obj.toMap());

  Stream<List<RoomObject>> watchRoomObjects(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('roomObjects')
      .snapshots()
      .map((s) => s.docs.map(RoomObject.fromDoc).toList());

  // ── Typing indicator ─────────────────────────────────────────────────────

  Future<void> setTyping(String coupleId, bool typing) => _db
      .collection('couples').doc(coupleId)
      .update({'typing.$_uid': typing ? Timestamp.now() : FieldValue.delete()});

  Stream<bool> watchPartnerTyping(String coupleId, String partnerUid) => _db
      .collection('couples').doc(coupleId)
      .snapshots()
      .map((d) {
        final ts = d.data()?['typing']?[partnerUid];
        if (ts == null) return false;
        final t = (ts as Timestamp).toDate();
        return DateTime.now().difference(t).inSeconds < 8;
      });

  // ── Truth Jar game ────────────────────────────────────────────────────────

  Future<void> submitTruth(String coupleId, String date, String answer) async {
    final ref = _db.collection('couples').doc(coupleId).collection('truths').doc(date);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({_uid: answer});
    } else {
      await ref.update({_uid: answer});
    }
  }

  Stream<Map<String, String>> watchTodayTruths(String coupleId) {
    final today = _todayKey();
    return _db.collection('couples').doc(coupleId).collection('truths').doc(today)
        .snapshots()
        .map((d) {
          if (!d.exists) return {};
          return Map<String, String>.from(
            (d.data() as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)));
        });
  }

  // ── Date Wheel ────────────────────────────────────────────────────────────

  Future<void> setDateWheelResult(String coupleId, String weekKey, int index) => _db
      .collection('couples').doc(coupleId).collection('dateWheel').doc(weekKey)
      .set({'index': index, 'chosenAt': FieldValue.serverTimestamp()});

  Stream<int?> watchDateWheelResult(String coupleId) {
    final now = DateTime.now();
    final weekKey = '${now.year}-W${_weekOfYear(now)}';
    return _db.collection('couples').doc(coupleId).collection('dateWheel').doc(weekKey)
        .snapshots()
        .map((d) => d.exists ? (d.data() as Map)['index'] as int? : null);
  }

  int _weekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return ((date.difference(startOfYear).inDays) / 7).ceil();
  }

  String get currentWeekKey {
    final now = DateTime.now();
    return '${now.year}-W${_weekOfYear(now)}';
  }

  // ── Compatibility score ───────────────────────────────────────────────────

  Future<Map<String, int>> getCompatibilityStats(String coupleId) async {
    final snap = await _db.collection('couples').doc(coupleId).collection('games').get();
    int total = 0, matched = 0;
    for (final doc in snap.docs) {
      final picks = (doc.data()['picks'] as Map<String, dynamic>?) ?? {};
      if (picks.length >= 2) {
        total++;
        if (picks.values.toSet().length == 1) matched++;
      }
    }
    return {'total': total, 'matched': matched};
  }

  // ── Games (Would You Rather) ──────────────────────────────────────────────

  Future<void> setTodayGame(String coupleId, GameRound game) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('games')
      .doc(game.date)
      .set(game.toMap());

  Future<void> pickGameOption(String coupleId, String date, String option) => _db
      .collection('couples')
      .doc(coupleId)
      .collection('games')
      .doc(date)
      .update({'picks.$_uid': option});

  Stream<GameRound?> watchTodayGame(String coupleId) {
    final today = _todayKey();
    return _db
        .collection('couples')
        .doc(coupleId)
        .collection('games')
        .doc(today)
        .snapshots()
        .map((d) => d.exists ? GameRound.fromDoc(d) : null);
  }

  // ── Scribble game ─────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>?> watchScribble(String coupleId) {
    final key = _todayKey();
    return _db.collection('couples').doc(coupleId)
        .collection('scribble').doc(key)
        .snapshots()
        .map((d) => d.exists ? d.data() : null);
  }

  Future<void> startScribble(String coupleId, String word, String drawerId) {
    final key = _todayKey();
    return _db.collection('couples').doc(coupleId)
        .collection('scribble').doc(key)
        .set({
          'word': word,
          'drawerId': drawerId,
          'strokes': [],
          'guesses': [],
          'status': 'drawing',
          'startedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> addScribbleStroke(
      String coupleId, List<Map<String, double>> pts, String color, double width) {
    final key = _todayKey();
    return _db.collection('couples').doc(coupleId)
        .collection('scribble').doc(key)
        .update({
          'strokes': FieldValue.arrayUnion([{
            'pts': pts.map((p) => {'x': p['x'], 'y': p['y']}).toList(),
            'color': color,
            'width': width,
            'by': _uid,
          }]),
        });
  }

  Future<void> clearScribbleCanvas(String coupleId) {
    final key = _todayKey();
    return _db.collection('couples').doc(coupleId)
        .collection('scribble').doc(key)
        .update({'strokes': []});
  }

  Future<void> submitScribbleGuess(String coupleId, String guess) async {
    final key = _todayKey();
    final ref = _db.collection('couples').doc(coupleId).collection('scribble').doc(key);
    final doc = await ref.get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final word = (data['word'] as String? ?? '').toLowerCase().trim();
    final correct = guess.toLowerCase().trim() == word;
    await ref.update({
      'guesses': FieldValue.arrayUnion([{
        'uid': _uid,
        'guess': guess,
        'correct': correct,
        'time': Timestamp.now(),
      }]),
      if (correct) 'status': 'correct',
    });
  }

  Future<void> resetScribble(String coupleId) {
    final key = _todayKey();
    return _db.collection('couples').doc(coupleId)
        .collection('scribble').doc(key)
        .delete();
  }

  // ── FCM token ─────────────────────────────────────────────────────────────

  Future<void> saveFCMToken(String token) => _db
      .collection('users').doc(_uid)
      .update({'fcmToken': token});

  Future<String?> getEmailByUsername(String username) async {
    final q = await _db.collection('users').where('username', isEqualTo: username).limit(1).get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.data()['email'] as String?;
  }

  // ── Avatar ────────────────────────────────────────────────────────────────

  Future<void> updateAvatarConfig(String uid, AvatarConfig config) =>
      _db.collection('users').doc(uid).update({'avatarConfig': config.toMap()});

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  double _randomPos() => (Random().nextDouble() * 4 - 2);
}
