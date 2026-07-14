import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/avatar/avatar_model.dart';

// ──────────────── User ────────────────

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final String? coupleId;
  final DateTime? birthday;
  final String? gender;
  final String? username;
  final String? nickname;
  final AvatarConfig? avatarConfig;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    this.coupleId,
    this.birthday,
    this.gender,
    this.username,
    this.nickname,
    this.avatarConfig,
  });

  /// The name shown around the app: the couple nickname if set,
  /// otherwise the first name.
  String get displayLabel => nickname?.isNotEmpty == true
      ? nickname!
      : displayName.split(' ').first;

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final avatarMap = d['avatarConfig'] as Map<String, dynamic>?;
    return UserModel(
      uid: doc.id,
      displayName: d['displayName'] ?? '',
      email: d['email'] ?? '',
      avatarUrl: d['avatarUrl'],
      coupleId: d['coupleId'],
      birthday: (d['birthday'] as Timestamp?)?.toDate(),
      gender: d['gender'],
      username: d['username'],
      nickname: d['nickname'],
      avatarConfig: avatarMap != null ? AvatarConfig.fromMap(avatarMap) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'avatarUrl': avatarUrl,
        'coupleId': coupleId,
        'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
        if (gender != null) 'gender': gender,
        if (username != null) 'username': username,
        if (nickname != null) 'nickname': nickname,
        if (avatarConfig != null) 'avatarConfig': avatarConfig!.toMap(),
      };

  UserModel copyWith({
    String? displayName,
    String? avatarUrl,
    String? coupleId,
    DateTime? birthday,
    String? gender,
    String? nickname,
    AvatarConfig? avatarConfig,
  }) =>
      UserModel(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        coupleId: coupleId ?? this.coupleId,
        birthday: birthday ?? this.birthday,
        gender: gender ?? this.gender,
        nickname: nickname ?? this.nickname,
        avatarConfig: avatarConfig ?? this.avatarConfig,
      );

  DateTime? get nextBirthday {
    if (birthday == null) return null;
    final now = DateTime.now();
    var next = DateTime(now.year, birthday!.month, birthday!.day);
    if (!next.isAfter(now)) next = DateTime(now.year + 1, birthday!.month, birthday!.day);
    return next;
  }
}

// ──────────────── Couple ────────────────

class CoupleModel {
  final String id;
  final List<String> members;
  final int themeColor;
  final DateTime? anniversary;
  final DateTime createdAt;
  final String? inviteCode;
  final String? chatBackground;
  final String? chatBackgroundUrl;

  const CoupleModel({
    required this.id,
    required this.members,
    required this.themeColor,
    this.anniversary,
    required this.createdAt,
    this.inviteCode,
    this.chatBackground,
    this.chatBackgroundUrl,
  });

  factory CoupleModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CoupleModel(
      id: doc.id,
      members: List<String>.from(d['members'] ?? []),
      themeColor: d['themeColor'] ?? 0xFFE8896A,
      anniversary: (d['anniversary'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      inviteCode: d['inviteCode'],
      chatBackground: d['chatBackground'] as String?,
      chatBackgroundUrl: d['chatBackgroundUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'members': members,
        'themeColor': themeColor,
        'anniversary': anniversary != null ? Timestamp.fromDate(anniversary!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
        'inviteCode': inviteCode,
        if (chatBackground != null) 'chatBackground': chatBackground,
        if (chatBackgroundUrl != null) 'chatBackgroundUrl': chatBackgroundUrl,
      };

  String partnerUid(String myUid) =>
      members.firstWhere((uid) => uid != myUid, orElse: () => '');
}

// ──────────────── Message ────────────────

enum MessageType { text, image, voice, reaction, video }

class MessageModel {
  final String id;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime sentAt;
  final bool readByPartner;
  final String? reactionEmoji;
  final bool isSnap;
  final bool snapViewed;
  final bool isWhisper;
  final String? replyToId;
  final String? replyToContent;
  final int? voiceDurationSeconds;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.sentAt,
    this.readByPartner = false,
    this.reactionEmoji,
    this.isSnap = false,
    this.snapViewed = false,
    this.isWhisper = false,
    this.replyToId,
    this.replyToContent,
    this.voiceDurationSeconds,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: d['senderId'] ?? '',
      content: d['content'] ?? '',
      type: MessageType.values.byName(d['type'] ?? 'text'),
      sentAt: (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readByPartner: d['readByPartner'] ?? false,
      reactionEmoji: d['reactionEmoji'],
      isSnap: d['isSnap'] ?? false,
      snapViewed: d['snapViewed'] ?? false,
      isWhisper: d['isWhisper'] ?? false,
      replyToId: d['replyToId'],
      replyToContent: d['replyToContent'],
      voiceDurationSeconds: d['voiceDurationSeconds'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'content': content,
        'type': type.name,
        'sentAt': Timestamp.fromDate(sentAt),
        'readByPartner': readByPartner,
        if (reactionEmoji != null) 'reactionEmoji': reactionEmoji,
        if (isSnap) 'isSnap': true,
        if (snapViewed) 'snapViewed': true,
        if (isWhisper) 'isWhisper': true,
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToContent != null) 'replyToContent': replyToContent,
        if (voiceDurationSeconds != null) 'voiceDurationSeconds': voiceDurationSeconds,
      };
}

// ──────────────── Mood ────────────────

enum MoodType { happy, excited, tired, sad, angry, stressed, inLove }

extension MoodEmoji on MoodType {
  String get emoji {
    switch (this) {
      case MoodType.happy: return '😊';
      case MoodType.excited: return '🤩';
      case MoodType.tired: return '😴';
      case MoodType.sad: return '😢';
      case MoodType.angry: return '😤';
      case MoodType.stressed: return '😰';
      case MoodType.inLove: return '🥰';
    }
  }

  String get label {
    switch (this) {
      case MoodType.happy: return 'Happy';
      case MoodType.excited: return 'Excited';
      case MoodType.tired: return 'Tired';
      case MoodType.sad: return 'Sad';
      case MoodType.angry: return 'Angry';
      case MoodType.stressed: return 'Stressed';
      case MoodType.inLove: return 'In Love';
    }
  }

  String get color {
    switch (this) {
      case MoodType.happy: return '#FFD166';
      case MoodType.excited: return '#FF6B8A';
      case MoodType.tired: return '#B8A0D9';
      case MoodType.sad: return '#5B9BD5';
      case MoodType.angry: return '#FF5252';
      case MoodType.stressed: return '#FF8C42';
      case MoodType.inLove: return '#FF6B8A';
    }
  }
}

String moodComboMessage(MoodType a, MoodType b) {
  if (a == b) {
    switch (a) {
      case MoodType.happy: return "You're both glowing today ✨";
      case MoodType.excited: return 'Double the energy! Go do something wild 🎉';
      case MoodType.tired: return 'Movie night, blankets, no plans 🛋️';
      case MoodType.sad: return "Hold each other tight. You'll get through it 💙";
      case MoodType.angry: return 'Mutual chaos mode. Breathe together 🌊';
      case MoodType.stressed: return 'Tag team stress — you handle it better together 💪';
      case MoodType.inLove: return "You're BOTH head over heels. Disgusting. Perfect. 💕";
    }
  }
  final combo = {a, b};
  if (combo.containsAll([MoodType.inLove, MoodType.tired])) return 'Tired but still completely in love 🥰';
  if (combo.containsAll([MoodType.happy, MoodType.sad])) return "One sunshine, one rain — you balance each other 🌦️";
  if (combo.containsAll([MoodType.excited, MoodType.tired])) return 'One is ready to GO, one needs coffee ☕';
  if (combo.containsAll([MoodType.stressed, MoodType.inLove])) return "Stressed but still thinking of them 💌";
  if (combo.containsAll([MoodType.angry, MoodType.inLove])) return 'Annoyed at the world, but not at each other 💪';
  if (combo.containsAll([MoodType.sad, MoodType.inLove])) return 'Love is the comfort on hard days 💙';
  if (combo.containsAll([MoodType.happy, MoodType.tired])) return "One's caffeinated, one's napping — perfect team ☀️";
  return 'Two different worlds, one shared heart 💫';
}

class MoodEntry {
  final String uid;
  final MoodType mood;
  final DateTime updatedAt;

  const MoodEntry({required this.uid, required this.mood, required this.updatedAt});

  factory MoodEntry.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MoodEntry(
      uid: doc.id,
      mood: MoodType.values.byName(d['mood'] ?? 'happy'),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  bool get isExpired => DateTime.now().difference(updatedAt).inHours >= 1;

  Map<String, dynamic> toMap() => {
        'mood': mood.name,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}

// ──────────────── Letter ────────────────

enum LetterUnlockType { tomorrow, nextMonth, birthday, anniversary, openWhenSad, custom }

class LetterModel {
  final String id;
  final String authorId;
  final String? receiverId;
  final String title;
  final String body;
  final LetterUnlockType unlockType;
  final DateTime? unlockAt;
  final bool opened;
  final DateTime createdAt;

  const LetterModel({
    required this.id,
    required this.authorId,
    this.receiverId,
    required this.title,
    required this.body,
    required this.unlockType,
    this.unlockAt,
    this.opened = false,
    required this.createdAt,
  });

  factory LetterModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LetterModel(
      id: doc.id,
      authorId: d['authorId'] ?? '',
      receiverId: d['receiverId'],
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      unlockType: LetterUnlockType.values.byName(d['unlockType'] ?? 'tomorrow'),
      unlockAt: (d['unlockAt'] as Timestamp?)?.toDate(),
      opened: d['opened'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  bool get isUnlocked {
    if (unlockType == LetterUnlockType.openWhenSad) return true;
    if (unlockAt == null) return true;
    return DateTime.now().isAfter(unlockAt!);
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        if (receiverId != null) 'receiverId': receiverId,
        'title': title,
        'body': body,
        'unlockType': unlockType.name,
        'unlockAt': unlockAt != null ? Timestamp.fromDate(unlockAt!) : null,
        'opened': opened,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ──────────────── Journal ────────────────

class JournalDay {
  final String id;
  final String? title;
  // Legacy fields kept for backwards-compatible reads
  final String? entryA;
  final String? entryB;
  final String? uidA;
  final String? uidB;
  final bool bothSubmitted;
  // New shared entry (either partner can write/edit)
  final String? sharedEntry;
  final String? lastEditedBy;

  const JournalDay({
    required this.id,
    this.title,
    this.entryA,
    this.entryB,
    this.uidA,
    this.uidB,
    this.bothSubmitted = false,
    this.sharedEntry,
    this.lastEditedBy,
  });

  /// The single content to display: prefer sharedEntry, fall back to entryA.
  String get content => sharedEntry ?? entryA ?? '';

  factory JournalDay.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return JournalDay(
      id: doc.id,
      title: d['title'] is String && (d['title'] as String).isNotEmpty
          ? d['title'] as String
          : null,
      entryA: d['entryA'] as String?,
      entryB: d['entryB'] as String?,
      uidA: d['uidA'] as String?,
      uidB: d['uidB'] as String?,
      bothSubmitted: d['bothSubmitted'] as bool? ?? false,
      sharedEntry: d['sharedEntry'] as String?,
      lastEditedBy: d['lastEditedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        if (title != null) 'title': title,
        'entryA': entryA,
        'entryB': entryB,
        'uidA': uidA,
        'uidB': uidB,
        'bothSubmitted': bothSubmitted,
        if (sharedEntry != null) 'sharedEntry': sharedEntry,
        if (lastEditedBy != null) 'lastEditedBy': lastEditedBy,
      };
}

// ──────────────── Memory ────────────────

class MemoryModel {
  final String id;
  final String uploaderUid;
  final String imageUrl;
  final String? caption;
  final DateTime? takenAt;
  final String? location;
  final bool favorite;
  final DateTime createdAt;
  final String? deletionRequestedBy;
  final String? collectionId;
  final bool isVideo;

  const MemoryModel({
    required this.id,
    required this.uploaderUid,
    required this.imageUrl,
    this.caption,
    this.takenAt,
    this.location,
    this.favorite = false,
    required this.createdAt,
    this.deletionRequestedBy,
    this.collectionId,
    this.isVideo = false,
  });

  factory MemoryModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MemoryModel(
      id: doc.id,
      uploaderUid: d['uploaderUid'] ?? '',
      imageUrl: d['imageUrl'] ?? '',
      caption: d['caption'],
      takenAt: (d['takenAt'] as Timestamp?)?.toDate(),
      location: d['location'],
      favorite: d['favorite'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deletionRequestedBy: d['deletionRequestedBy'],
      collectionId: d['collectionId'],
      isVideo: d['isVideo'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'uploaderUid': uploaderUid,
        'imageUrl': imageUrl,
        'caption': caption,
        'takenAt': takenAt != null ? Timestamp.fromDate(takenAt!) : null,
        'location': location,
        'favorite': favorite,
        'createdAt': Timestamp.fromDate(createdAt),
        'deletionRequestedBy': deletionRequestedBy,
        'isVideo': isVideo,
        if (collectionId != null) 'collectionId': collectionId,
      };
}

// ──────────────── Photo Collection ────────────────

class PhotoCollection {
  final String id;
  final String name;
  final String? coverUrl;
  final String createdBy;
  final DateTime createdAt;
  final int photoCount;

  const PhotoCollection({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.createdBy,
    required this.createdAt,
    this.photoCount = 0,
  });

  factory PhotoCollection.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PhotoCollection(
      id: doc.id,
      name: d['name'] ?? '',
      coverUrl: d['coverUrl'],
      createdBy: d['createdBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      photoCount: d['photoCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (coverUrl != null) 'coverUrl': coverUrl,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'photoCount': photoCount,
      };
}

// ──────────────── Bucket List ────────────────

enum BucketStatus { someday, planned, done }

class BucketItem {
  final String id;
  final String title;
  final String? note;
  final BucketStatus status;
  final String? linkedMemoryId;
  final DateTime createdAt;
  final String? addedBy;

  const BucketItem({
    required this.id,
    required this.title,
    this.note,
    this.status = BucketStatus.someday,
    this.linkedMemoryId,
    required this.createdAt,
    this.addedBy,
  });

  factory BucketItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BucketItem(
      id: doc.id,
      title: d['title'] ?? '',
      note: d['note'],
      status: BucketStatus.values.byName(d['status'] ?? 'someday'),
      linkedMemoryId: d['linkedMemoryId'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      addedBy: d['addedBy'],
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'note': note,
        'status': status.name,
        'linkedMemoryId': linkedMemoryId,
        'createdAt': Timestamp.fromDate(createdAt),
        if (addedBy != null) 'addedBy': addedBy,
      };
}

// ──────────────── Place Pin ────────────────

class PlacePin {
  final String id;
  final String name;
  final String? note;
  final double lat;
  final double lng;
  final String? emoji;
  final bool visited;
  final DateTime createdAt;
  final String createdBy;

  const PlacePin({
    required this.id,
    required this.name,
    this.note,
    required this.lat,
    required this.lng,
    this.emoji,
    this.visited = false,
    required this.createdAt,
    required this.createdBy,
  });

  factory PlacePin.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PlacePin(
      id: doc.id,
      name: d['name'] ?? '',
      note: d['note'],
      lat: (d['lat'] ?? 0.0).toDouble(),
      lng: (d['lng'] ?? 0.0).toDouble(),
      emoji: d['emoji'],
      visited: d['visited'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: d['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (note != null) 'note': note,
        'lat': lat,
        'lng': lng,
        if (emoji != null) 'emoji': emoji,
        'visited': visited,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdBy': createdBy,
      };
}

// ──────────────── Book Wish ────────────────

/// Per-user reading position inside a book PDF.
class BookProgress {
  final int page; // 0-based page index
  final int totalPages;
  final DateTime updatedAt;

  const BookProgress({
    required this.page,
    required this.totalPages,
    required this.updatedAt,
  });

  factory BookProgress.fromMap(Map<String, dynamic> m) => BookProgress(
        page: (m['page'] ?? 0) as int,
        totalPages: (m['totalPages'] ?? 0) as int,
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'page': page,
        'totalPages': totalPages,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}

class BookWish {
  final String id;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? pdfUrl;
  final String? note;
  final bool read;
  final String addedBy;
  final DateTime addedAt;

  /// uid → last reading position (both partners tracked independently)
  final Map<String, BookProgress> progress;

  const BookWish({
    required this.id,
    required this.title,
    this.author,
    this.coverUrl,
    this.pdfUrl,
    this.note,
    this.read = false,
    required this.addedBy,
    required this.addedAt,
    this.progress = const {},
  });

  factory BookWish.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final progressRaw = d['progress'] as Map<String, dynamic>? ?? {};
    return BookWish(
      id: doc.id,
      title: d['title'] ?? '',
      author: d['author'],
      coverUrl: d['coverUrl'],
      pdfUrl: d['pdfUrl'],
      note: d['note'],
      read: d['read'] ?? false,
      addedBy: d['addedBy'] ?? '',
      addedAt: (d['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      progress: progressRaw.map((uid, v) =>
          MapEntry(uid, BookProgress.fromMap(v as Map<String, dynamic>))),
    );
  }

  BookProgress? progressOf(String? uid) => uid == null ? null : progress[uid];

  Map<String, dynamic> toMap() => {
        'title': title,
        if (author != null) 'author': author,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (pdfUrl != null) 'pdfUrl': pdfUrl,
        if (note != null) 'note': note,
        'read': read,
        'addedBy': addedBy,
        'addedAt': Timestamp.fromDate(addedAt),
        if (progress.isNotEmpty)
          'progress': progress.map((uid, p) => MapEntry(uid, p.toMap())),
      };
}

/// A note pinned to a specific page of a book, visible to both partners.
class BookNote {
  final String id;
  final int page; // 0-based page index
  final String authorId;
  final String text;
  final DateTime createdAt;

  const BookNote({
    required this.id,
    required this.page,
    required this.authorId,
    required this.text,
    required this.createdAt,
  });

  factory BookNote.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BookNote(
      id: doc.id,
      page: (d['page'] ?? 0) as int,
      authorId: d['authorId'] ?? '',
      text: d['text'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'page': page,
        'authorId': authorId,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ──────────────── Room Object ────────────────

enum RoomObjectType { photoFrame, letterEnvelope, journalBook, bucketTrophy, gift }

class RoomObject {
  final String id;
  final RoomObjectType type;
  final String sourceRef;
  final Map<String, double> position;
  final DateTime createdAt;

  const RoomObject({
    required this.id,
    required this.type,
    required this.sourceRef,
    required this.position,
    required this.createdAt,
  });

  factory RoomObject.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final pos = d['position'] as Map<String, dynamic>? ?? {};
    return RoomObject(
      id: doc.id,
      type: RoomObjectType.values.byName(d['type'] ?? 'photoFrame'),
      sourceRef: d['sourceRef'] ?? '',
      position: {
        'x': (pos['x'] ?? 0.0).toDouble(),
        'y': (pos['y'] ?? 0.0).toDouble(),
        'z': (pos['z'] ?? 0.0).toDouble(),
      },
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'sourceRef': sourceRef,
        'position': position,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ──────────────── Home Decor (isometric shared room) ────────────────

/// A single placed piece of furniture/decor in the couple's shared room.
class HomeDecorItem {
  final String id;
  final String catalogId; // key into the static kHomeDecorCatalog list
  final int col;
  final int row;
  final int rotation; // 0/90/180/270 — ignored by items that don't rotate
  final String placedBy;
  final DateTime placedAt;

  const HomeDecorItem({
    required this.id,
    required this.catalogId,
    required this.col,
    required this.row,
    this.rotation = 0,
    required this.placedBy,
    required this.placedAt,
  });

  factory HomeDecorItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return HomeDecorItem(
      id: doc.id,
      catalogId: d['catalogId'] ?? '',
      col: (d['col'] ?? 0) as int,
      row: (d['row'] ?? 0) as int,
      rotation: (d['rotation'] ?? 0) as int,
      placedBy: d['placedBy'] ?? '',
      placedAt: (d['placedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'catalogId': catalogId,
        'col': col,
        'row': row,
        'rotation': rotation,
        'placedBy': placedBy,
        'placedAt': Timestamp.fromDate(placedAt),
      };
}

/// The couple's chosen floor / wall / lighting style — one shared singleton
/// per couple, following the same doc shape as cinema/listen sessions.
class HomeRoomStyle {
  final String floorId;
  final String wallId;
  final String lightingId;

  const HomeRoomStyle({
    this.floorId = 'oak',
    this.wallId = 'cream_paint',
    this.lightingId = 'warm',
  });

  factory HomeRoomStyle.fromDoc(DocumentSnapshot doc) {
    if (!doc.exists) return const HomeRoomStyle();
    final d = doc.data() as Map<String, dynamic>;
    return HomeRoomStyle(
      floorId: d['floorId'] ?? 'oak',
      wallId: d['wallId'] ?? 'cream_paint',
      lightingId: d['lightingId'] ?? 'warm',
    );
  }
}

// ──────────────── Wildcards (special favor/grace cards) ────────────────

enum WildcardRank {
  ace, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king, joker
}

enum WildcardSuit { hearts, diamonds, clubs, spades }

class WildCard {
  final String id;
  final String favorText;
  final WildcardRank rank;
  final WildcardSuit? suit; // null when rank == joker
  final String givenBy;
  final DateTime givenAt;
  final bool redeemed;
  final DateTime? redeemedAt;
  final String? requestId; // set if this card fulfilled a request

  const WildCard({
    required this.id,
    required this.favorText,
    required this.rank,
    this.suit,
    required this.givenBy,
    required this.givenAt,
    this.redeemed = false,
    this.redeemedAt,
    this.requestId,
  });

  factory WildCard.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final suitName = d['suit'] as String?;
    return WildCard(
      id: doc.id,
      favorText: d['favorText'] ?? '',
      rank: WildcardRank.values.byName(d['rank'] ?? 'joker'),
      suit: suitName == null ? null : WildcardSuit.values.byName(suitName),
      givenBy: d['givenBy'] ?? '',
      givenAt: (d['givenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      redeemed: d['redeemed'] ?? false,
      redeemedAt: (d['redeemedAt'] as Timestamp?)?.toDate(),
      requestId: d['requestId'],
    );
  }

  Map<String, dynamic> toMap() => {
        'favorText': favorText,
        'rank': rank.name,
        if (suit != null) 'suit': suit!.name,
        'givenBy': givenBy,
        'givenAt': Timestamp.fromDate(givenAt),
        'redeemed': redeemed,
        if (redeemedAt != null) 'redeemedAt': Timestamp.fromDate(redeemedAt!),
        if (requestId != null) 'requestId': requestId,
      };
}

enum WildcardRequestStatus { pending, approved, declined }

class WildcardRequest {
  final String id;
  final String? note;
  final String requestedBy;
  final DateTime requestedAt;
  final WildcardRequestStatus status;

  const WildcardRequest({
    required this.id,
    this.note,
    required this.requestedBy,
    required this.requestedAt,
    this.status = WildcardRequestStatus.pending,
  });

  factory WildcardRequest.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return WildcardRequest(
      id: doc.id,
      note: d['note'],
      requestedBy: d['requestedBy'] ?? '',
      requestedAt: (d['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: WildcardRequestStatus.values.byName(d['status'] ?? 'pending'),
    );
  }

  Map<String, dynamic> toMap() => {
        if (note != null) 'note': note,
        'requestedBy': requestedBy,
        'requestedAt': Timestamp.fromDate(requestedAt),
        'status': status.name,
      };
}

// ──────────────── Game Round (Would You Rather) ────────────────

class GameRound {
  final String date;
  final int questionIndex;
  final String optionA;
  final String optionB;
  final Map<String, String> picks;

  const GameRound({
    required this.date,
    required this.questionIndex,
    required this.optionA,
    required this.optionB,
    required this.picks,
  });

  bool get bothPicked => picks.length >= 2;
  bool get matched => bothPicked && picks.values.toSet().length == 1;

  factory GameRound.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GameRound(
      date: doc.id,
      questionIndex: d['questionIndex'] ?? 0,
      optionA: d['optionA'] ?? '',
      optionB: d['optionB'] ?? '',
      picks: Map<String, String>.from(d['picks'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'questionIndex': questionIndex,
        'optionA': optionA,
        'optionB': optionB,
        'picks': picks,
      };
}
