import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
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
  ChatBackground _background = ChatBackground.dark;

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
    setState(() => _sending = true);
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
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (picked == null || !mounted) return;
    setState(() => _sending = true);
    HapticFeedback.mediumImpact();
    try {
      final bytes = await picked.readAsBytes();
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

  BoxDecoration _backgroundDecoration() {
    final asset = _chatBgAssets[_background];
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

  void _showBackgroundPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BackgroundPickerSheet(
        current: _background,
        onSelect: (bg) {
          setState(() => _background = bg);
          Navigator.pop(context);
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
      body: Container(
        decoration: _backgroundDecoration(),
        child: Column(
          children: [
            _ChatAppBar(
              partner: partner,
              accent: accent,
              isTyping: isTyping,
              partnerOnline: partnerOnline,
              onBackgroundTap: () => _showBackgroundPicker(context),
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
                            hasWallpaper: _background != ChatBackground.dark,
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

            _ChatInput(
              controller: _controller,
              sending: _sending,
              whisperMode: _whisperMode,
              accent: accent,
              onSend: _send,
              onSnap: _sendSnap,
              onToggleWhisper: () =>
                  setState(() => _whisperMode = !_whisperMode),
            ),
          ],
        ),
      ),
    );
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

  const _ChatAppBar({
    required this.partner,
    required this.accent,
    required this.isTyping,
    required this.partnerOnline,
    this.onBackgroundTap,
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
  final void Function(ChatBackground) onSelect;

  const _BackgroundPickerSheet({
    required this.current,
    required this.onSelect,
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
              itemCount: _imageOptions.length + 1, // +1 for Dark
              itemBuilder: (_, i) {
                final bg = i == 0 ? ChatBackground.dark : _imageOptions[i - 1];
                final isSelected = current == bg;
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

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool whisperMode;
  final Color accent;
  final VoidCallback onSend;
  final VoidCallback onSnap;
  final VoidCallback onToggleWhisper;

  const _ChatInput({
    required this.controller,
    required this.sending,
    required this.whisperMode,
    required this.accent,
    required this.onSend,
    required this.onSnap,
    required this.onToggleWhisper,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.bgMid,
          border: Border(
            top: BorderSide(
              color: whisperMode
                  ? AppColors.lavender.withValues(alpha: 0.5)
                  : AppColors.divider,
              width: whisperMode ? 1.0 : 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onSnap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('📷', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: whisperMode
                        ? AppColors.lavender.withValues(alpha: 0.4)
                        : AppColors.divider,
                    width: 0.5,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontStyle:
                        whisperMode ? FontStyle.italic : FontStyle.normal,
                  ),
                  decoration: InputDecoration(
                    hintText: whisperMode
                        ? 'Whisper something… 🌙'
                        : 'Say something ♡',
                    hintStyle:
                        const TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  maxLines: 4,
                  minLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onToggleWhisper,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: whisperMode
                      ? AppColors.lavender.withValues(alpha: 0.2)
                      : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: whisperMode
                        ? AppColors.lavender.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child:
                    const Text('🌙', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: sending ? null : onSend,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [accent, AppColors.coral]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: sending
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

class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final Color accent;
  final bool hasWallpaper;
  final void Function(String) onReact;
  final VoidCallback? onDelete;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.accent,
    required this.hasWallpaper,
    required this.onReact,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (msg.isSnap) return _snap(context);
    if (msg.isWhisper) return _whisper(context);
    return _text(context);
  }

  Widget _text(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _reactSheet(context),
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
                child: Text(
                  msg.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
              if (msg.reactionEmoji != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(msg.reactionEmoji!,
                      style: const TextStyle(fontSize: 16)),
                ),
              Padding(
                padding:
                    const EdgeInsets.only(top: 2, left: 2, right: 2),
                child: Text(
                  timeago.format(msg.sentAt, allowFromNow: true),
                  style: TextStyle(
                      color: hasWallpaper
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColors.textMuted,
                      fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
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
                  'Snap · ${timeago.format(msg.sentAt, allowFromNow: true)}',
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
    if (onDelete == null) return;
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
                onDelete!();
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

  void _reactSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding:
            const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['❤️', '😂', '😮', '😢', '🔥', '👏']
                  .map((e) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          onReact(e);
                        },
                        child: Text(e,
                            style:
                                const TextStyle(fontSize: 32)),
                      ))
                  .toList(),
            ),
          ],
        ),
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
