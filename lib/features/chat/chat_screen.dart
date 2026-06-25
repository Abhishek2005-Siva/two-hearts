import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      await ref.read(firestoreServiceProvider).sendMessage(
        coupleId,
        MessageModel(
          id: const Uuid().v4(),
          senderId: authUser.uid,
          content: text,
          type: MessageType.text,
          sentAt: DateTime.now(),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final messagesAsync = ref.watch(messagesProvider);
    final accent = ref.watch(accentColorProvider);
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final uid = authUser.uid;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.bgGradient,
          ),
        ),
        child: Column(
          children: [
            _ChatAppBar(partner: partner, accent: accent),
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.rose)),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.textSecondary))),
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
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) => _MessageBubble(
                      msg: messages[i],
                      isMe: messages[i].senderId == uid,
                      accent: accent,
                    ).animate().fadeIn(delay: Duration(milliseconds: i < 10 ? i * 30 : 0)),
                  );
                },
              ),
            ),
            _ChatInput(
              controller: _controller,
              sending: _sending,
              accent: accent,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatAppBar extends StatelessWidget {
  final dynamic partner;
  final Color accent;
  const _ChatAppBar({this.partner, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.bgMid,
          border: const Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accent, AppColors.coral],
                ),
              ),
              child: Center(
                child: Text(
                  partner?.displayName.isNotEmpty == true
                      ? partner!.displayName[0].toUpperCase()
                      : '♡',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partner?.displayName ?? 'Your person',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Just for you two', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final Color accent;

  const _MessageBubble({required this.msg, required this.isMe, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 4, bottom: 4,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                gradient: isMe
                    ? LinearGradient(colors: [accent, AppColors.coral])
                    : null,
                color: isMe ? null : AppColors.bgCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                border: isMe ? null : Border.all(color: AppColors.divider, width: 0.5),
                boxShadow: isMe
                    ? [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  fontSize: 15,
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
            if (msg.reactionEmoji != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(msg.reactionEmoji!, style: const TextStyle(fontSize: 16)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeago.format(msg.sentAt, locale: 'en_short'),
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.readByPartner ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 12,
                      color: msg.readByPartner ? accent : AppColors.textMuted,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final Color accent;
  final VoidCallback onSend;

  const _ChatInput({
    required this.controller,
    required this.sending,
    required this.accent,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 12, top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Say something sweet…',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: sending
                    ? null
                    : LinearGradient(colors: [accent, AppColors.coral]),
                color: sending ? AppColors.bgCard : null,
                shape: BoxShape.circle,
                boxShadow: sending
                    ? null
                    : [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
