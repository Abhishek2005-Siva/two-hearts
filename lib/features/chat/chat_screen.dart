import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/cloudinary_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _isTyping = false;
  bool _whisperMode = false;
  String? _viewingSnapId;
  final _scheduledDeletes = <String>{};

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  void _onTextChanged() {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final typing = _ctrl.text.isNotEmpty;
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

  void _scheduleWhisperDelete(MessageModel msg) {
    if (_scheduledDeletes.contains(msg.id)) return;
    _scheduledDeletes.add(msg.id);
    Future.delayed(const Duration(seconds: 30), () {
      final coupleId = ref.read(coupleIdProvider);
      if (coupleId != null) {
        ref.read(firestoreServiceProvider).deleteMessage(coupleId, msg.id).ignore();
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null) return;
    _ctrl.clear();
    _isTyping = false;
    ref.read(firestoreServiceProvider).setTyping(coupleId, false).ignore();
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
          isWhisper: _whisperMode,
        ),
      );
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendSnap() async {
    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null) return;
    final xfile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75);
    if (xfile == null || !mounted) return;
    setState(() => _sending = true);
    HapticFeedback.mediumImpact();
    try {
      final bytes = await xfile.readAsBytes();
      final url = await CloudinaryService.uploadImage(bytes, folder: 'two_hearts/$coupleId/snaps');
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
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(150.ms, () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: 300.ms, curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId != null) {
      ref.read(firestoreServiceProvider).setTyping(coupleId, false).ignore();
    }
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final messagesAsync = ref.watch(messagesProvider);
    final accent = ref.watch(accentColorProvider);
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final isTyping = ref.watch(partnerTypingProvider).valueOrNull ?? false;
    final partnerOnline = ref.watch(partnerOnlineProvider).valueOrNull ?? false;
    final uid = authUser.uid;
    final now = DateTime.now();

    ref.listen(messagesProvider, (_, next) {
      final msgs = next.valueOrNull;
      if (msgs == null) return;
      _markRead();
      for (final m in msgs) {
        if (m.isWhisper && m.readByPartner) _scheduleWhisperDelete(m);
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: RoomTod.bgGradient(now),
          ),
        ),
        child: Column(
          children: [
            _ChatAppBar(
              partner: partner,
              accent: accent,
              isTyping: isTyping,
              partnerOnline: partnerOnline,
            ),
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.rose)),
                error: (e, _) => _ErrorView(error: e),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('💌', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 16),
                        Text('Send your first message ♡', style: Theme.of(context).textTheme.bodyMedium),
                      ]),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final showDate = i == 0 || messages[i - 1].sentAt.day != msg.sentAt.day;
                      return Column(
                        children: [
                          if (showDate) _DateSep(date: msg.sentAt),
                          _MessageBubble(
                            msg: msg,
                            isMe: msg.senderId == uid,
                            accent: accent,
                            isViewingSnap: _viewingSnapId == msg.id,
                            onReact: (emoji) {
                              HapticFeedback.selectionClick();
                              final coupleId = ref.read(coupleIdProvider);
                              if (coupleId == null) return;
                              ref.read(firestoreServiceProvider)
                                  .reactToMessage(coupleId, msg.id, emoji).ignore();
                            },
                            onHoldSnap: () {
                              setState(() => _viewingSnapId = msg.id);
                              if (!msg.snapViewed) {
                                Future.delayed(800.ms, () {
                                  final coupleId = ref.read(coupleIdProvider);
                                  if (coupleId != null && mounted) {
                                    ref.read(firestoreServiceProvider)
                                        .viewSnap(coupleId, msg.id).ignore();
                                  }
                                });
                              }
                            },
                            onReleaseSnap: () => setState(() => _viewingSnapId = null),
                          ).animate().fadeIn(delay: Duration(milliseconds: i < 10 ? i * 15 : 0)),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            _ChatInput(
              controller: _ctrl,
              sending: _sending,
              accent: accent,
              whisperMode: _whisperMode,
              onSend: _send,
              onSnap: _sendSnap,
              onToggleWhisper: () => setState(() => _whisperMode = !_whisperMode),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App Bar ────────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget {
  final dynamic partner;
  final Color accent;
  final bool isTyping;
  final bool partnerOnline;
  const _ChatAppBar({this.partner, required this.accent, required this.isTyping, required this.partnerOnline});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [accent, AppColors.coral]),
                boxShadow: partnerOnline
                    ? [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 10)]
                    : null,
              ),
              child: Center(
                child: Text(
                  partner?.displayName.isNotEmpty == true
                      ? partner!.displayName[0].toUpperCase() : '♡',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(partner?.displayName ?? 'Your person',
                      style: Theme.of(context).textTheme.titleMedium),
                  AnimatedSwitcher(
                    duration: 300.ms,
                    child: isTyping
                        ? Row(
                            key: const ValueKey('typing'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TypingDot(delay: 0), _TypingDot(delay: 150), _TypingDot(delay: 300),
                              const SizedBox(width: 5),
                              const Text('typing…', style: TextStyle(color: AppColors.rose, fontSize: 11, fontStyle: FontStyle.italic)),
                            ],
                          )
                        : Text(
                            key: const ValueKey('status'),
                            partnerOnline ? 'online ♡' : 'just for you two',
                            style: TextStyle(
                              color: partnerOnline ? const Color(0xFF44EE88) : AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5, height: 5,
      margin: const EdgeInsets.only(right: 3),
      decoration: const BoxDecoration(color: AppColors.rose, shape: BoxShape.circle),
    ).animate(onPlay: (c) => c.repeat())
        .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
        .then().fadeOut(duration: 400.ms);
  }
}

// ── Date Separator ─────────────────────────────────────────────────────────

class _DateSep extends StatelessWidget {
  final DateTime date;
  const _DateSep({required this.date});

  String _label() {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        const Expanded(child: Divider(color: AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(_label(),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.5)),
        ),
        const Expanded(child: Divider(color: AppColors.divider)),
      ]),
    );
  }
}

// ── Message Bubble ─────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final Color accent;
  final bool isViewingSnap;
  final void Function(String) onReact;
  final VoidCallback onHoldSnap;
  final VoidCallback onReleaseSnap;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.accent,
    required this.isViewingSnap,
    required this.onReact,
    required this.onHoldSnap,
    required this.onReleaseSnap,
  });

  void _showReactionPicker(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('React', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '😂', '😢', '😮', '🔥', '💕', '🥺', '✨']
                  .map((e) => GestureDetector(
                        onTap: () { Navigator.pop(context); onReact(e); },
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (msg.isSnap) return _snap(context);
    if (msg.isWhisper) return _whisper(context);
    return _text(context);
  }

  Widget _text(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 3, bottom: 3, left: isMe ? 56 : 0, right: isMe ? 0 : 56),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: () => _showReactionPicker(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  gradient: isMe ? LinearGradient(colors: [accent, AppColors.coral]) : null,
                  color: isMe ? null : AppColors.bgCard,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  border: isMe ? null : Border.all(color: AppColors.divider, width: 0.5),
                  boxShadow: isMe
                      ? [BoxShadow(color: accent.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Text(msg.content,
                    style: TextStyle(fontSize: 15, color: isMe ? Colors.white : AppColors.textPrimary, height: 1.45)),
              ),
            ),
            if (msg.reactionEmoji != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider, width: 0.5),
                  ),
                  child: Text(msg.reactionEmoji!, style: const TextStyle(fontSize: 14)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(timeago.format(msg.sentAt, locale: 'en_short'),
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.readByPartner ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 12,
                    color: msg.readByPartner ? accent : AppColors.textMuted,
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _whisper(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 3, bottom: 3, left: isMe ? 56 : 0, right: isMe ? 0 : 56),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: () => _showReactionPicker(context),
              child: Opacity(
                opacity: 0.65,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? accent.withValues(alpha: 0.3) : AppColors.bgCard.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isMe ? accent.withValues(alpha: 0.4) : AppColors.divider.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🌙 whisper',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 9, letterSpacing: 0.5)),
                      const SizedBox(height: 3),
                      Text(msg.content,
                          style: TextStyle(
                            fontSize: 14,
                            color: isMe ? Colors.white.withValues(alpha: 0.85) : AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          )),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Text(
                msg.readByPartner ? 'read · fading soon' : timeago.format(msg.sentAt, locale: 'en_short'),
                style: TextStyle(
                  fontSize: 9,
                  color: msg.readByPartner ? accent.withValues(alpha: 0.6) : AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _snap(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 4, bottom: 4, left: isMe ? 40 : 0, right: isMe ? 0 : 40),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPressStart: (_) => onHoldSnap(),
          onLongPressEnd: (_) => onReleaseSnap(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 160, height: 200,
              child: msg.snapViewed
                  ? Container(
                      color: AppColors.bgCard,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('👻', style: TextStyle(fontSize: 36)),
                          SizedBox(height: 8),
                          Text('Snap viewed', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    )
                  : isViewingSnap
                      ? Image.network(msg.content, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(color: AppColors.bgCard))
                      : Container(
                          color: isMe ? accent.withValues(alpha: 0.3) : AppColors.bgCard,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(isMe ? '📷' : '👻', style: const TextStyle(fontSize: 40)),
                              const SizedBox(height: 10),
                              Text(isMe ? 'Snap sent' : 'Hold to view',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              if (!isMe)
                                const Text('disappears after',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                            ],
                          ),
                        ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Chat Input ─────────────────────────────────────────────────────────────

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final Color accent;
  final bool whisperMode;
  final VoidCallback onSend;
  final VoidCallback onSnap;
  final VoidCallback onToggleWhisper;

  const _ChatInput({
    required this.controller,
    required this.sending,
    required this.accent,
    required this.whisperMode,
    required this.onSend,
    required this.onSnap,
    required this.onToggleWhisper,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 200.ms,
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: AppColors.bgMid,
        border: Border(
          top: BorderSide(
            color: whisperMode ? accent.withValues(alpha: 0.3) : AppColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (whisperMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Row(children: [
                Text('🌙 Whisper — fades after they read',
                    style: TextStyle(color: accent.withValues(alpha: 0.8), fontSize: 11, fontStyle: FontStyle.italic)),
              ]),
            ),
          Row(
            children: [
              // Camera / snap
              GestureDetector(
                onTap: sending ? null : onSnap,
                child: Container(
                  width: 40, height: 40,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.divider, width: 0.5),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.textSecondary, size: 19),
                ),
              ),
              // Text field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: whisperMode ? accent.withValues(alpha: 0.08) : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: whisperMode ? accent.withValues(alpha: 0.3) : AppColors.divider,
                      width: 0.5,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontStyle: whisperMode ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 4, minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: whisperMode ? 'Whisper something…' : 'Say something sweet…',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Whisper toggle
              GestureDetector(
                onTap: onToggleWhisper,
                child: AnimatedContainer(
                  duration: 200.ms,
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: whisperMode ? accent.withValues(alpha: 0.2) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: whisperMode ? accent.withValues(alpha: 0.5) : AppColors.divider,
                    ),
                  ),
                  child: const Center(child: Text('🌙', style: TextStyle(fontSize: 16))),
                ),
              ),
              const SizedBox(width: 8),
              // Send button
              GestureDetector(
                onTap: sending ? null : onSend,
                child: AnimatedContainer(
                  duration: 200.ms,
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accent, AppColors.coral]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: sending
                      ? const Padding(padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Error View ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final Object error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    final isPermission = error.toString().contains('PERMISSION_DENIED') ||
        error.toString().contains('permission-denied');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(isPermission ? '🔒' : '⚠️', style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 14),
          Text(isPermission ? 'Firestore access blocked' : 'Could not load messages',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            isPermission
                ? 'Go to Firebase Console → Firestore → Rules and publish the firestore.rules file.'
                : error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
        ]),
      ),
    );
  }
}
