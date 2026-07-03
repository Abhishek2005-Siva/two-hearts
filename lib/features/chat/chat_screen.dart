import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_sound/flutter_sound.dart' hide PlayerState;
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'snap_camera_screen.dart';
import 'package:video_player/video_player.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/cloudinary_service.dart';

// ── Background enum ───────────────────────────────────────────────────────

enum ChatBackground {
  dark,
  bg1, bg2, bg3, bg4, bg5, bg6, bg7, bg8, bg9, bg10,
}

const _chatBgAssets = {
  ChatBackground.bg1:  'assets/images/chat_bg1.png',
  ChatBackground.bg2:  'assets/images/chat_bg2.png',
  ChatBackground.bg3:  'assets/images/chat_bg3.jpg',
  ChatBackground.bg4:  'assets/images/chat_bg4.jpg',
  ChatBackground.bg5:  'assets/images/chat_bg5.jpeg',
  ChatBackground.bg6:  'assets/images/chat_bg6.jpeg',
  ChatBackground.bg7:  'assets/images/chat_bg7.jpeg',
  ChatBackground.bg8:  'assets/images/chat_bg8.jpeg',
  ChatBackground.bg9:  'assets/images/chat_bg9.jpg',
  ChatBackground.bg10: 'assets/images/chat_bg10.jpeg',
};

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _isTyping = false;
  bool _whisperMode = false;
  final _scheduledDeletes = <String>{};
  MessageModel? _replyingTo;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  void _onTextChanged() {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final typing = _controller.text.isNotEmpty;
    if (typing != _isTyping) {
      _isTyping = typing;
      ref.read(firestoreServiceProvider).setTyping(coupleId, typing).ignore();
    }
  }

  void _markRead() {
    final coupleId = ref.read(coupleIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final messages = ref.read(messagesProvider).valueOrNull;
    if (coupleId == null || uid == null || messages == null) return;
    final unread = messages
        .where((m) => m.senderId != uid && !m.readByPartner)
        .map((m) => m.id)
        .toList();
    if (unread.isNotEmpty) {
      ref.read(firestoreServiceProvider).markMessagesRead(coupleId, unread).ignore();
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null) return;
    _controller.clear();
    _isTyping = false;
    ref.read(firestoreServiceProvider).setTyping(coupleId, false).ignore();
    final isWhisper = _whisperMode;
    final replyTo = _replyingTo;
    setState(() {
      _sending = true;
      _replyingTo = null;
    });
    HapticFeedback.lightImpact();
    try {
      await ref.read(firestoreServiceProvider).sendMessage(
        coupleId,
        MessageModel(
          id: const Uuid().v4(),
          senderId: authUser.uid,
          content: text,
          type: MessageType.text,
          sentAt: DateTime.now(),
          isWhisper: isWhisper,
          replyToId: replyTo?.id,
          replyToContent: replyTo?.content,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendSnap() async {
    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null) return;

    final result = await Navigator.of(context).push<SnapCameraCapture>(
      MaterialPageRoute(builder: (_) => const SnapCameraScreen(), fullscreenDialog: true),
    );
    if (result == null || !mounted) return;

    setState(() => _sending = true);
    HapticFeedback.mediumImpact();
    try {
      if (result.type == SnapCameraResult.photo) {
        final bytes = await File(result.path).readAsBytes();
        final url = await CloudinaryService.uploadImage(bytes, folder: 'snaps');
        await ref.read(firestoreServiceProvider).sendMessage(
          coupleId,
          MessageModel(
            id: const Uuid().v4(),
            senderId: authUser.uid,
            content: url,
            type: MessageType.image,
            sentAt: DateTime.now(),
            isSnap: true,
          ),
        );
      } else {
        final url = await CloudinaryService.uploadVideo(File(result.path), folder: 'snaps');
        await ref.read(firestoreServiceProvider).sendMessage(
          coupleId,
          MessageModel(
            id: const Uuid().v4(),
            senderId: authUser.uid,
            content: url,
            type: MessageType.video,
            sentAt: DateTime.now(),
            isSnap: true,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendVoice(String path, int durationSeconds) async {
    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null) return;
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    try {
      final url = await CloudinaryService.uploadAudio(File(path));
      await ref.read(firestoreServiceProvider).sendMessage(
        coupleId,
        MessageModel(
          id: const Uuid().v4(),
          senderId: authUser.uid,
          content: url,
          type: MessageType.voice,
          sentAt: DateTime.now(),
          voiceDurationSeconds: durationSeconds,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scheduleWhisperDelete(String msgId, String coupleId) {
    if (_scheduledDeletes.contains(msgId)) return;
    _scheduledDeletes.add(msgId);
    Future.delayed(const Duration(seconds: 30), () {
      ref.read(firestoreServiceProvider).deleteMessage(coupleId, msgId).ignore();
    });
  }

  BoxDecoration _backgroundDecoration(ChatBackground background, String? customBgUrl) {
    if (customBgUrl != null) {
      // Custom network image — rendered via CachedNetworkImage in a Stack instead;
      // return transparent here and let build() handle the network layer.
      return const BoxDecoration();
    }
    final asset = _chatBgAssets[background];
    if (asset != null) {
      return BoxDecoration(
        image: DecorationImage(
          image: AssetImage(asset),
          fit: BoxFit.cover,
        ),
      );
    }
    // Default dark gradient
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: AppColors.bgGradient,
      ),
    );
  }

  Future<void> _pickGalleryBackground() async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final url = await CloudinaryService.uploadImage(bytes, folder: 'chat_bg');
    if (!mounted) return;
    await ref.read(firestoreServiceProvider).setChatBackground(
      coupleId,
      ChatBackground.dark.name,
      customUrl: url,
    );
  }

  void _showBackgroundPicker(BuildContext context, ChatBackground current, String? customBgUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BackgroundPickerSheet(
        current: current,
        customBgUrl: customBgUrl,
        onSelect: (bg) {
          final coupleId = ref.read(coupleIdProvider);
          if (coupleId != null) {
            ref.read(firestoreServiceProvider)
                .setChatBackground(coupleId, bg.name)
                .ignore();
          }
          Navigator.pop(context);
        },
        onGalleryPick: () {
          Navigator.pop(context);
          _pickGalleryBackground();
        },
      ),
    );
  }

  @override
  void dispose() {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId != null) {
      ref.read(firestoreServiceProvider).setTyping(coupleId, false).ignore();
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final messagesAsync = ref.watch(messagesProvider);
    final accent = ref.watch(accentColorProvider);
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final isTyping = ref.watch(partnerTypingProvider).valueOrNull ?? false;
    final partnerOnline = ref.watch(partnerOnlineProvider).valueOrNull ?? false;
    final uid = authUser.uid;
    final coupleId = ref.watch(coupleIdProvider);
    final couple = ref.watch(coupleProvider).valueOrNull;
    final backgroundName = couple?.chatBackground ?? ChatBackground.dark.name;
    final customBgUrl = couple?.chatBackgroundUrl;
    final background = ChatBackground.values.firstWhere(
      (b) => b.name == backgroundName,
      orElse: () => ChatBackground.dark,
    );

    ref.listen(messagesProvider, (_, next) {
      if (next.valueOrNull != null) _markRead();
      if (coupleId != null) {
        for (final msg in next.valueOrNull ?? []) {
          if (msg.isWhisper && msg.readByPartner && msg.senderId != uid) {
            _scheduleWhisperDelete(msg.id, coupleId);
          }
        }
      }
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (customBgUrl != null)
            CachedNetworkImage(
              imageUrl: customBgUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: Colors.black),
              errorWidget: (_, _, _) => Container(color: Colors.black),
            ),
          Container(
        decoration: _backgroundDecoration(background, customBgUrl),
        child: Column(
          children: [
            _ChatAppBar(
              partner: partner,
              accent: accent,
              isTyping: isTyping,
              partnerOnline: partnerOnline,
              onBackgroundTap: () => _showBackgroundPicker(context, background, customBgUrl),
              onVideoCall: _startVideoCall,
            ),
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.rose)),
                error: (e, _) {
                  final isPermission = e.toString().contains('PERMISSION_DENIED') ||
                      e.toString().contains('permission-denied');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(isPermission ? '🔒' : '⚠️',
                              style: const TextStyle(fontSize: 44)),
                          const SizedBox(height: 14),
                          Text(
                            isPermission
                                ? 'Firestore access blocked'
                                : 'Could not load messages',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isPermission
                                ? 'Go to Firebase Console → Firestore → Rules and publish the rules from the repo.'
                                : e.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💌', style: TextStyle(fontSize: 56)),
                          const SizedBox(height: 16),
                          Text('Send your first message ♡',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    );
                  }
                  // reverse:true with original ascending list → newest at bottom
                  final reversed = messages.reversed.toList();
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: reversed.length,
                    itemBuilder: (context, i) {
                      final msg = reversed[i];
                      final prevMsg =
                          i < reversed.length - 1 ? reversed[i + 1] : null;
                      final showDate = prevMsg == null ||
                          !_sameDay(msg.sentAt, prevMsg.sentAt);
                      return Column(
                        children: [
                          if (showDate) _DateSep(date: msg.sentAt),
                          _MessageBubble(
                            msg: msg,
                            isMe: msg.senderId == uid,
                            accent: accent,
                            hasWallpaper: background != ChatBackground.dark || customBgUrl != null,
                            onReact: (emoji) {
                              HapticFeedback.selectionClick();
                              if (coupleId == null) return;
                              ref
                                  .read(firestoreServiceProvider)
                                  .reactToMessage(coupleId, msg.id, emoji)
                                  .ignore();
                            },
                            onDelete: coupleId == null ? null : () {
                              ref
                                  .read(firestoreServiceProvider)
                                  .deleteMessage(coupleId, msg.id)
                                  .ignore();
                            },
                            onReply: () {
                              setState(() => _replyingTo = msg);
                            },
                            onDoubleTap: coupleId == null ? null : () {
                              final isLiked = msg.reactionEmoji == '❤️';
                              HapticFeedback.lightImpact();
                              ref
                                  .read(firestoreServiceProvider)
                                  .reactToMessage(coupleId, msg.id, isLiked ? '' : '❤️')
                                  .ignore();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // Whisper banner
            if (_whisperMode)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                color: AppColors.bgCard,
                child: Row(
                  children: [
                    const Text('🌙', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Whisper — fades 30 s after they read',
                        style: TextStyle(
                            color: AppColors.lavender, fontSize: 12),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _whisperMode = false),
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.textMuted, size: 16),
                    ),
                  ],
                ),
              ),

            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.bgCard,
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, color: AppColors.rose, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Replying to: "${_replyingTo!.content.length > 60 ? '${_replyingTo!.content.substring(0, 60)}…' : _replyingTo!.content}"',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _replyingTo = null),
                      child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 16),
                    ),
                  ],
                ),
              ),
            // Typing indicator — shown directly above the input box
            if (isTyping)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  children: [
                    Text(
                      '${partner?.displayName.split(' ').first ?? 'Partner'} is typing',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const _TypingDots(),
                  ],
                ),
              ),
            _ChatInput(
              controller: _controller,
              sending: _sending,
              whisperMode: _whisperMode,
              accent: accent,
              onSend: _send,
              onSnap: _sendSnap,
              onToggleWhisper: () =>
                  setState(() => _whisperMode = !_whisperMode),
              onSendVoice: _sendVoice,
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  Future<void> _startVideoCall() async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      await ref.read(firestoreServiceProvider).sendMessage(
        coupleId,
        MessageModel(
          id: const Uuid().v4(),
          senderId: authUser.uid,
          content: '📹 Started a video call — join at meet.jit.si/twohearts-$coupleId',
          type: MessageType.text,
          sentAt: DateTime.now(),
          isSnap: false,
        ),
      );
    }

    final url = Uri.parse('https://meet.jit.si/twohearts-$coupleId');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── App Bar ───────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget {
  final UserModel? partner;
  final Color accent;
  final bool isTyping;
  final bool partnerOnline;
  final VoidCallback? onBackgroundTap;
  final VoidCallback? onVideoCall;

  const _ChatAppBar({
    required this.partner,
    required this.accent,
    required this.isTyping,
    required this.partnerOnline,
    this.onBackgroundTap,
    this.onVideoCall,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        color: const Color(0xFF0D0D0D),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            if (partner?.avatarUrl != null)
              CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(partner!.avatarUrl!))
            else
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.2),
                child: Text(
                  partner?.displayName.isNotEmpty == true
                      ? partner!.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/snaps'),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner?.displayName.split(' ').first ?? 'Partner',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    if (isTyping)
                      Text('typing…',
                          style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontStyle: FontStyle.italic))
                    else if (partnerOnline)
                      Row(children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50),
                              shape: BoxShape.circle),
                        ),
                        const Text('online',
                            style: TextStyle(
                                color: Color(0xFF4CAF50), fontSize: 11)),
                      ]),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.videocam_outlined,
                  color: AppColors.textSecondary, size: 22),
              onPressed: onVideoCall,
              tooltip: 'Video call',
            ),
            IconButton(
              icon: const Icon(Icons.wallpaper_outlined,
                  color: AppColors.textMuted, size: 20),
              onPressed: onBackgroundTap,
              tooltip: 'Chat background',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Background Picker Sheet ───────────────────────────────────────────────

class _BackgroundPickerSheet extends StatelessWidget {
  final ChatBackground current;
  final String? customBgUrl;
  final void Function(ChatBackground) onSelect;
  final VoidCallback onGalleryPick;

  const _BackgroundPickerSheet({
    required this.current,
    required this.customBgUrl,
    required this.onSelect,
    required this.onGalleryPick,
  });

  static final _imageOptions = [
    ChatBackground.bg1,  ChatBackground.bg2,  ChatBackground.bg3,
    ChatBackground.bg4,  ChatBackground.bg5,  ChatBackground.bg6,
    ChatBackground.bg7,  ChatBackground.bg8,  ChatBackground.bg9,
    ChatBackground.bg10,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      padding: EdgeInsets.fromLTRB(
        24, 20, 24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Text(
            'Chat Background',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.65,
              ),
              itemCount: _imageOptions.length + 2, // +1 Dark, +1 Gallery
              itemBuilder: (_, i) {
                // Last tile = Gallery picker
                if (i == _imageOptions.length + 1) {
                  final isSelected = customBgUrl != null;
                  return GestureDetector(
                    onTap: onGalleryPick,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: customBgUrl != null
                              ? CachedNetworkImage(imageUrl: customBgUrl!, fit: BoxFit.cover)
                              : Container(
                                  color: AppColors.bgCardLight,
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.photo_library_outlined,
                                          color: AppColors.textSecondary, size: 28),
                                      SizedBox(height: 6),
                                      Text('Gallery',
                                          style: TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.rose : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: isSelected
                              ? const Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircleAvatar(
                                      radius: 10,
                                      backgroundColor: AppColors.rose,
                                      child: Icon(Icons.check_rounded,
                                          color: Colors.white, size: 13),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  );
                }

                final bg = i == 0 ? ChatBackground.dark : _imageOptions[i - 1];
                final isSelected = customBgUrl == null && current == bg;
                final asset = _chatBgAssets[bg];
                return GestureDetector(
                  onTap: () => onSelect(bg),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: asset != null
                            ? Image.asset(asset, fit: BoxFit.cover)
                            : Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: AppColors.bgGradient,
                                  ),
                                ),
                                child: const Center(
                                  child: Text('Dark',
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12)),
                                ),
                              ),
                      ),
                      // Selection border + checkmark
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.rose : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected
                            ? const Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.all(6),
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: AppColors.rose,
                                    child: Icon(Icons.check_rounded,
                                        color: Colors.white, size: 13),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                ),
              );
            },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input ─────────────────────────────────────────────────────────────────

class _ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final bool whisperMode;
  final Color accent;
  final VoidCallback onSend;
  final VoidCallback onSnap;
  final VoidCallback onToggleWhisper;
  final Future<void> Function(String path, int durationSeconds) onSendVoice;

  const _ChatInput({
    required this.controller,
    required this.sending,
    required this.whisperMode,
    required this.accent,
    required this.onSend,
    required this.onSnap,
    required this.onToggleWhisper,
    required this.onSendVoice,
  });

  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
  final _recorder = FlutterSoundRecorder();
  bool _recorderReady = false;
  bool _isRecording = false;
  bool _isUploading = false;
  String? _recordPath;
  Timer? _recordTimer;
  Duration _recordDuration = Duration.zero;
  double _dragOffsetX = 0;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      await _recorder.openRecorder();
      if (mounted) setState(() => _recorderReady = true);
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!_recorderReady) {
      await _initRecorder();
      if (!_recorderReady) return;
    }
    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder.startRecorder(toFile: _recordPath, codec: Codec.aacADTS);
    HapticFeedback.mediumImpact();
    if (mounted) setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
      _dragOffsetX = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopAndPreview() async {
    _recordTimer?.cancel();
    await _recorder.stopRecorder();
    final path = _recordPath;
    final durationSecs = _recordDuration.inSeconds;
    if (mounted) setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
      _dragOffsetX = 0;
    });
    if (path == null || durationSecs < 1) return;
    if (!mounted) return;
    // Show preview sheet — user can listen before deciding to send
    final shouldSend = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _VoicePreviewSheet(
        filePath: path,
        duration: Duration(seconds: durationSecs),
      ),
    );
    if (shouldSend == true && mounted) {
      setState(() => _isUploading = true);
      try {
        await widget.onSendVoice(path, durationSecs);
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _recorder.stopRecorder();
    HapticFeedback.lightImpact();
    if (mounted) setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
      _dragOffsetX = 0;
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: _isRecording
              ? AppColors.bgMid
              : AppColors.bgMid,
          border: Border(
            top: BorderSide(
              color: _isRecording
                  ? Colors.red.withValues(alpha: 0.4)
                  : widget.whisperMode
                      ? AppColors.lavender.withValues(alpha: 0.5)
                      : AppColors.divider,
              width: _isRecording || widget.whisperMode ? 1.0 : 0.5,
            ),
          ),
        ),
        child: _isRecording ? _buildRecordingRow() : _buildNormalRow(context, hasText),
      ),
    );
  }

  Widget _buildRecordingRow() {
    final isCancelZone = _dragOffsetX < -60;
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx < 0) {
          setState(() => _dragOffsetX =
              (_dragOffsetX + details.delta.dx).clamp(-120.0, 0.0));
        }
      },
      onHorizontalDragEnd: (_) {
        if (_dragOffsetX < -80) {
          _cancelRecording();
        } else {
          setState(() => _dragOffsetX = 0);
        }
      },
      child: Row(
        children: [
          // Pulsing red dot
          _PulsingDot(),
          const SizedBox(width: 10),
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedOpacity(
              opacity: isCancelZone ? 1.0 : 0.6,
              duration: const Duration(milliseconds: 150),
              child: Text(
                isCancelZone ? 'Release to cancel' : '  Slide to cancel ←',
                style: TextStyle(
                  color: isCancelZone ? Colors.redAccent : AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // Release to send button
          GestureDetector(
            onTap: _stopAndPreview,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stop_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalRow(BuildContext context, bool hasText) {
    return Row(
      children: [
        GestureDetector(
          onTap: widget.onSnap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.camera_alt_outlined,
                color: AppColors.textSecondary, size: 22),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.whisperMode
                    ? AppColors.lavender.withValues(alpha: 0.4)
                    : AppColors.divider,
                width: 0.5,
              ),
            ),
            child: TextField(
              controller: widget.controller,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontStyle: widget.whisperMode
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              decoration: InputDecoration(
                hintText: widget.whisperMode
                    ? 'Whisper something… 🌙'
                    : 'Say something ♡',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => widget.onSend(),
              maxLines: 4,
              minLines: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: widget.onToggleWhisper,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.whisperMode
                  ? AppColors.lavender.withValues(alpha: 0.2)
                  : AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.whisperMode
                    ? AppColors.lavender.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: const Text('🌙', style: TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: 8),
        // Mic button (when no text) or Send button (when has text or sending)
        if (_isUploading)
          const SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.rose),
              ),
            ),
          )
        else if (!hasText)
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) {
              if (_isRecording) _stopAndPreview();
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.mic_none_rounded,
                  color: AppColors.textSecondary, size: 20),
            ),
          )
        else
          GestureDetector(
            onTap: widget.sending ? null : widget.onSend,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [widget.accent, AppColors.coral]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: widget.sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
      ],
    );
  }
}

// ── Voice preview sheet (shown after releasing mic) ───────────────────────

class _VoicePreviewSheet extends StatefulWidget {
  final String filePath;
  final Duration duration;
  const _VoicePreviewSheet({required this.filePath, required this.duration});
  @override
  State<_VoicePreviewSheet> createState() => _VoicePreviewSheetState();
}

class _VoicePreviewSheetState extends State<_VoicePreviewSheet> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playing = false; _pos = Duration.zero; });
    });
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Voice Note', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Row(children: [
            GestureDetector(
              onTap: () async {
                if (_playing) {
                  await _player.pause();
                } else {
                  await _player.play(DeviceFileSource(widget.filePath));
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.rose, shape: BoxShape.circle),
                child: Icon(_playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                  child: Slider(
                    value: _pos.inSeconds.toDouble(),
                    max: widget.duration.inSeconds > 0 ? widget.duration.inSeconds.toDouble() : 1,
                    activeColor: AppColors.rose,
                    inactiveColor: Colors.white24,
                    onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(_fmt(widget.duration),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              ],
            )),
          ]),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Discard', style: TextStyle(color: AppColors.textMuted)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rose,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.send_rounded, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text('Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            )),
          ]),
        ],
      ),
    );
  }
}

// ── Typing Dots ───────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = (_ctrl.value - delay).clamp(0.0, 1.0);
            final offset = (t < 0.5 ? t * 2 : 2 - t * 2) * 4.0;
            return Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              transform: Matrix4.translationValues(0, -offset, 0),
              decoration: const BoxDecoration(
                color: AppColors.textMuted,
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Pulsing dot indicator ─────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Date Separator ────────────────────────────────────────────────────────

class _DateSep extends StatelessWidget {
  final DateTime date;
  const _DateSep({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    final String label;
    if (diff == 0) {
      label = 'Today';
    } else if (diff == 1) {
      label = 'Yesterday';
    } else {
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      label = '${months[date.month]} ${date.day}'
          '${date.year != now.year ? ', ${date.year}' : ''}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(
            child: Divider(color: AppColors.divider, thickness: 0.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
        ),
        const Expanded(
            child: Divider(color: AppColors.divider, thickness: 0.5)),
      ]),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────

// ── Emoji data ────────────────────────────────────────────────────────────

const _kQuickEmojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];
const _kAllEmojis = {
  'Smileys': ['😊','😂','🤣','😍','🥰','😘','😁','😎','🤩','🥳','😏','😒','🙄','😔','😢','😭','😤','😡','🤬','😱'],
  'Gestures': ['👍','👎','👏','🙌','🤝','✌️','🤞','👌','🤙','💪','🫶','❤️‍🔥','🫂'],
  'Hearts': ['❤️','🧡','💛','💚','💙','💜','🖤','🤍','💕','💞','💓','💗','💖','💝','💘','💟'],
  'Nature': ['🌸','🌺','🌻','🌹','🍀','🌿','🌈','⭐','🌙','☀️','🌊','🦋','🐝'],
  'Food': ['🍕','🍔','🍰','🍩','🍫','🍓','🍑','🍜','🧁','☕','🧃','🍷'],
  'Activities': ['🎮','🎵','🎬','📸','✈️','🏖️','🎉','🎁','🏃','💃','🕺'],
};

class _MessageBubble extends StatefulWidget {
  final MessageModel msg;
  final bool isMe;
  final Color accent;
  final bool hasWallpaper;
  final void Function(String) onReact;
  final VoidCallback? onDelete;
  final VoidCallback onReply;
  final VoidCallback? onDoubleTap;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.accent,
    required this.hasWallpaper,
    required this.onReact,
    required this.onReply,
    this.onDelete,
    this.onDoubleTap,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  double _dragOffset = 0;

  // Convenience getters
  MessageModel get msg => widget.msg;
  bool get isMe => widget.isMe;
  Color get accent => widget.accent;
  bool get hasWallpaper => widget.hasWallpaper;

  @override
  Widget build(BuildContext context) {
    if (msg.isSnap) return _snap(context);
    if (msg.isWhisper) return _whisper(context);
    if (msg.type == MessageType.voice) return _voice(context);
    return _text(context);
  }

  Widget _swipeWrapper(BuildContext context, Widget child) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final dx = details.delta.dx;
        // isMe bubbles swipe left (negative), partner bubbles swipe right (positive)
        if (isMe && dx < 0) {
          setState(() => _dragOffset = (_dragOffset + dx).clamp(-60.0, 0.0));
        } else if (!isMe && dx > 0) {
          setState(() => _dragOffset = (_dragOffset + dx).clamp(0.0, 60.0));
        }
      },
      onHorizontalDragEnd: (_) {
        if (_dragOffset.abs() >= 50) {
          HapticFeedback.lightImpact();
          widget.onReply();
        }
        setState(() => _dragOffset = 0);
      },
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: child,
      ),
    );
  }

  Widget _text(BuildContext context) {
    final bubbleContent = GestureDetector(
      onLongPress: () => _reactSheet(context),
      onDoubleTap: widget.onDoubleTap,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(colors: [accent, AppColors.coral])
                      : null,
                  color: isMe
                      ? null
                      : hasWallpaper
                          ? Colors.black.withValues(alpha: 0.58)
                          : AppColors.bgCardLight,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: (!isMe && hasWallpaper)
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 0.5)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.replyToContent != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: const Border(
                              left: BorderSide(
                                  color: AppColors.rose, width: 3)),
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          msg.replyToContent!.length > 80
                              ? '${msg.replyToContent!.substring(0, 80)}…'
                              : msg.replyToContent!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    Text(
                      msg.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (msg.reactionEmoji != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(msg.reactionEmoji!,
                      style: const TextStyle(fontSize: 16)),
                ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);

    return _swipeWrapper(context, bubbleContent);
  }

  Widget _whisper(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Opacity(
        opacity: 0.7,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.lavender.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: AppColors.lavender.withValues(alpha: 0.3),
                width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('🌙', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 4),
                Text('whisper',
                    style: TextStyle(
                        color: AppColors.lavender,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
              ]),
              const SizedBox(height: 4),
              Text(
                msg.content,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    height: 1.4,
                    fontStyle: FontStyle.italic),
              ),
              if (msg.readByPartner && !isMe) ...[
                const SizedBox(height: 4),
                Text('read · fading soon',
                    style: TextStyle(
                        color: AppColors.lavender,
                        fontSize: 10,
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _snap(BuildContext context) {
    final isExpired =
        DateTime.now().difference(msg.sentAt) > const Duration(hours: 24);

    // Expired snaps show nothing — just a subtle label
    if (isExpired) return const SizedBox.shrink();

    final isVideo = msg.type == MessageType.video;

    return GestureDetector(
      onLongPress: () => _snapDeleteSheet(context),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (isVideo)
                GestureDetector(
                  onTap: () => _openVideoPlayer(context, msg.content),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 160,
                      height: 200,
                      color: Colors.black87,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _openFullscreen(context, msg.content),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 160,
                      height: 200,
                      child: CachedNetworkImage(
                        imageUrl: msg.content,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: AppColors.bgCard,
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.rose, strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.bgCard,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: AppColors.textMuted, size: 32),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 2, right: 2),
                child: Text(
                  isVideo ? 'Video Snap' : 'Snap',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  void _snapDeleteSheet(BuildContext context) {
    if (widget.onDelete == null) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onDelete!();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3), width: 1),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Delete Snap',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _openFullscreen(BuildContext context, String url) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) => _FullscreenImageView(url: url),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  static void _openVideoPlayer(BuildContext context, String url) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) => _FullscreenVideoView(url: url),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  Widget _voice(BuildContext context) {
    return _swipeWrapper(
      context,
      GestureDetector(
        onLongPress: () => _reactSheet(context),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: _VoiceBubble(msg: msg, isMe: isMe, accent: accent),
          ),
        ),
      ).animate().fadeIn(duration: 200.ms),
    );
  }

  void _reactSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmojiPickerSheet(onPick: (e) {
        Navigator.pop(context);
        widget.onReact(e);
      }),
    );
  }
}

// ── Voice Bubble ─────────────────────────────────────────────────────────

class _VoiceBubble extends StatefulWidget {
  final MessageModel msg;
  final bool isMe;
  final Color accent;

  const _VoiceBubble({
    required this.msg,
    required this.isMe,
    required this.accent,
  });

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    final knownSecs = widget.msg.voiceDurationSeconds;
    if (knownSecs != null && knownSecs > 0) {
      _total = Duration(seconds: knownSecs);
    }
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _total = dur);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _position = Duration.zero; });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.msg.content));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total.inMilliseconds > 0
        ? (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final totalLabel = _total > Duration.zero ? _fmt(_total) : '--:--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: widget.isMe
            ? LinearGradient(colors: [widget.accent, AppColors.coral])
            : null,
        color: widget.isMe ? null : AppColors.bgCardLight,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
          bottomRight: Radius.circular(widget.isMe ? 4 : 18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.35),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (v) async {
                      final target = Duration(
                          milliseconds: (v * _total.inMilliseconds).round());
                      await _audioPlayer.seek(target);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '${_fmt(_position)} / $totalLabel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Emoji Picker Sheet ────────────────────────────────────────────────────

class _EmojiPickerSheet extends StatelessWidget {
  final void Function(String) onPick;
  const _EmojiPickerSheet({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Quick-pick row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _kQuickEmojis
                .map((e) => GestureDetector(
                      onTap: () => onPick(e),
                      child: Text(e, style: const TextStyle(fontSize: 32)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 10),
          // Scrollable category list
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _kAllEmojis.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(entry.key,
                          style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                    ),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: entry.value.length,
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => onPick(entry.value[i]),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(entry.value[i],
                                style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fullscreen Image Viewer ───────────────────────────────────────────────

class _FullscreenImageView extends StatelessWidget {
  final String url;
  const _FullscreenImageView({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.rose, strokeWidth: 2),
                ),
                errorWidget: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
          // Close button — top-right
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fullscreen Video Player ───────────────────────────────────────────────

class _FullscreenVideoView extends StatefulWidget {
  final String url;
  const _FullscreenVideoView({required this.url});

  @override
  State<_FullscreenVideoView> createState() => _FullscreenVideoViewState();
}

class _FullscreenVideoViewState extends State<_FullscreenVideoView> {
  late final VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _initialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(color: AppColors.rose),
          ),
          if (_initialized)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                }),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
