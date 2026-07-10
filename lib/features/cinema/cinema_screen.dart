import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/cloudinary_service.dart';
import 'share_target_screen.dart';

/// Watch Together — one shared video, play/pause/seek mirrored between the
/// two phones through Firestore. Whoever touches the controls drives; the
/// other phone follows within ~a second.
class CinemaScreen extends ConsumerWidget {
  const CinemaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(cinemaSessionProvider);

    return session.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Text('Could not load movie night\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
      ),
      data: (data) {
        if (data == null || data['videoUrl'] == null) {
          return const _MovieNightLanding();
        }
        return _CinemaPlayer(
          key: ValueKey(data['videoUrl']),
          session: data,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Landing — no movie playing yet
// ═══════════════════════════════════════════════════════════════════════════

class _MovieNightLanding extends ConsumerStatefulWidget {
  const _MovieNightLanding();

  @override
  ConsumerState<_MovieNightLanding> createState() => _MovieNightLandingState();
}

class _MovieNightLandingState extends ConsumerState<_MovieNightLanding> {
  bool _busy = false;
  String _busyLabel = '';

  Future<void> _startWithUrl() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _VideoLinkDialog(),
    );
    if (result == null) return;
    await _start(result.$1, result.$2);
  }

  Future<void> _startWithUpload() async {
    final picked =
        await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _TitleDialog(),
    );
    if (title == null || !mounted) return;

    setState(() {
      _busy = true;
      _busyLabel = 'Uploading your movie…\nthis can take a few minutes';
    });
    try {
      final url = await CloudinaryService.uploadVideo(File(picked.path),
          folder: 'two_hearts/cinema');
      await _start(url, title);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _startScreenShare() async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final partnerName = ref
        .read(partnerUserProvider)
        .valueOrNull
        ?.displayName
        .split(' ')
        .first;
    final callId = const Uuid().v4();
    // Nudge the partner so the incoming prompt fires even in the background.
    ref
        .read(firestoreServiceProvider)
        .notifyScreenShare(coupleId)
        .ignore();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ShareTargetScreen(
        coupleId: coupleId,
        callId: callId,
        partnerName: partnerName,
      ),
    ));
  }

  Future<void> _start(String url, String title) async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    setState(() {
      _busy = true;
      _busyLabel = 'Opening the theater…';
    });
    try {
      await ref
          .read(firestoreServiceProvider)
          .startCinemaSession(coupleId, url, title);
      // cinemaSessionProvider will rebuild into the player.
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start movie night: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final partnerName = ref
            .watch(partnerUserProvider)
            .valueOrNull
            ?.displayName
            .split(' ')
            .first ??
        'your person';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.bgGradient,
          ),
        ),
        child: SafeArea(
          child: _busy
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(_busyLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.textSecondary, height: 1.5)),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      backgroundColor: Colors.transparent,
                      title: const Text('Movie Night'),
                      leading: BackButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Marquee card
                            Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: AppColors.cardGradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                    color: AppColors.divider, width: 0.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.12),
                                    blurRadius: 40,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const Text('🍿',
                                          style: TextStyle(fontSize: 56))
                                      .animate(
                                          onPlay: (c) =>
                                              c.repeat(reverse: true))
                                      .scale(
                                          begin: const Offset(1, 1),
                                          end: const Offset(1.08, 1.08),
                                          duration: 1400.ms,
                                          curve: Curves.easeInOut),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Watch a movie\nwith $partnerName',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            height: 1.25),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Play, pause and skip together — perfectly '
                                    'in sync on both phones, wherever you are.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                        height: 1.5),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn().slideY(begin: 0.05),
                            const SizedBox(height: 28),
                            _SourceButton(
                              emoji: '🔗',
                              title: 'Play from a link',
                              subtitle: 'Paste a direct video link (mp4, webm…)',
                              accent: accent,
                              onTap: _startWithUrl,
                            ).animate().fadeIn(delay: 120.ms).slideX(begin: -0.04),
                            const SizedBox(height: 14),
                            _SourceButton(
                              emoji: '📤',
                              title: 'Upload from this phone',
                              subtitle: 'Pick a video from your gallery to share',
                              accent: accent,
                              onTap: _startWithUpload,
                            ).animate().fadeIn(delay: 220.ms).slideX(begin: -0.04),
                            const SizedBox(height: 14),
                            _SourceButton(
                              emoji: '🖥️',
                              title: 'Share my screen',
                              subtitle:
                                  'Mirror your phone live — watch anything together',
                              accent: accent,
                              onTap: _startScreenShare,
                            ).animate().fadeIn(delay: 320.ms).slideX(begin: -0.04),
                            const SizedBox(height: 20),
                            const Text(
                              'Starting a movie sends them a little\n'
                              '"come watch with me" nudge ♡',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _SourceButton({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SquishyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.cardGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent, size: 22),
          ],
        ),
      ),
    );
  }
}

class _VideoLinkDialog extends StatefulWidget {
  const _VideoLinkDialog();

  @override
  State<_VideoLinkDialog> createState() => _VideoLinkDialogState();
}

class _VideoLinkDialogState extends State<_VideoLinkDialog> {
  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _urlCtrl.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      setState(() => _error = 'That doesn\'t look like a valid link');
      return;
    }
    Navigator.of(context).pop((url, _titleCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Play from a link'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlCtrl,
            autofocus: true,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'https://…/movie.mp4',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Movie title (optional)',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Needs a direct video file link — a page URL like a '
            'YouTube link won\'t play.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Start ▶')),
      ],
    );
  }
}

class _TitleDialog extends StatefulWidget {
  const _TitleDialog();

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('What are we watching?'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(hintText: 'Movie title (optional)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Upload'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Player — session active
// ═══════════════════════════════════════════════════════════════════════════

class _CinemaPlayer extends ConsumerStatefulWidget {
  final Map<String, dynamic> session;
  const _CinemaPlayer({super.key, required this.session});

  @override
  ConsumerState<_CinemaPlayer> createState() => _CinemaPlayerState();
}

class _CinemaPlayerState extends ConsumerState<_CinemaPlayer> {
  VideoPlayerController? _video;
  String? _initError;
  bool _applyingRemote = false;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  bool _scrubbing = false;
  double _scrubValue = 0;

  Timer? _heartbeat;
  Timer? _controlsTimer;
  Timer? _driftTimer;

  StreamSubscription? _reactionsSub;
  final _seenReactions = <String>{};
  final _floatingReactions = <_FloatingReaction>[];
  bool _reactionsPrimed = false;

  String get _myUid => FirebaseAuth.instance.currentUser!.uid;
  String? get _coupleId => ref.read(coupleIdProvider);

  static const _reactionEmojis = ['❤️', '😂', '😭', '😱', '🥰', '🍿'];

  @override
  void initState() {
    super.initState();
    _initVideo();
    _startHeartbeat();
    _listenReactions();
    _scheduleControlsHide();
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _controlsTimer?.cancel();
    _driftTimer?.cancel();
    _reactionsSub?.cancel();
    final coupleId = _coupleId;
    if (coupleId != null) {
      ref.read(firestoreServiceProvider).leaveCinema(coupleId).ignore();
    }
    _video?.dispose();
    if (_fullscreen) _exitFullscreenChrome();
    super.dispose();
  }

  // ── setup ────────────────────────────────────────────────────────────────

  Future<void> _initVideo() async {
    final url = widget.session['videoUrl'] as String;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _video = ctrl;
    try {
      await ctrl.initialize();
    } catch (e) {
      if (mounted) {
        setState(() => _initError =
            'This video couldn\'t be played.\nCheck the link is a direct video file.');
      }
      return;
    }
    if (!mounted) return;
    // Land where the session currently is.
    _applySession(widget.session, force: true);
    // Gentle drift correction while playing: if we drift >2.5s from the
    // session clock, snap back (handles buffering hiccups on one side).
    _driftTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final s = ref.read(cinemaSessionProvider).valueOrNull;
      if (s != null && !_scrubbing) _applySession(s, driftOnly: true);
    });
    setState(() {});
  }

  void _startHeartbeat() {
    final coupleId = _coupleId;
    if (coupleId == null) return;
    final svc = ref.read(firestoreServiceProvider);
    svc.cinemaHeartbeat(coupleId).ignore();
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      svc.cinemaHeartbeat(coupleId).ignore();
    });
  }

  void _listenReactions() {
    final coupleId = _coupleId;
    if (coupleId == null) return;
    _reactionsSub = ref
        .read(firestoreServiceProvider)
        .watchCinemaReactions(coupleId)
        .listen((reactions) {
      if (!_reactionsPrimed) {
        // First snapshot = history; don't replay old reactions.
        _seenReactions.addAll(reactions.map((r) => r['id'] as String));
        _reactionsPrimed = true;
        return;
      }
      for (final r in reactions) {
        final id = r['id'] as String;
        if (_seenReactions.add(id)) {
          _spawnFloatingReaction(r['emoji'] as String? ?? '❤️');
        }
      }
    });
  }

  // ── sync engine ──────────────────────────────────────────────────────────

  /// Where the shared session says the movie should be *right now*.
  Duration _sessionPosition(Map<String, dynamic> s) {
    final base = Duration(milliseconds: (s['positionMs'] as num?)?.toInt() ?? 0);
    if (s['isPlaying'] != true) return base;
    final updatedAt = (s['updatedAt'] as Timestamp?)?.toDate();
    if (updatedAt == null) return base;
    final elapsed = DateTime.now().difference(updatedAt);
    return base + (elapsed.isNegative ? Duration.zero : elapsed);
  }

  void _applySession(Map<String, dynamic> s,
      {bool force = false, bool driftOnly = false}) {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    // Ignore our own echoes unless forced (initial load / drift check).
    if (!force && !driftOnly && s['updatedBy'] == _myUid) return;

    final shouldPlay = s['isPlaying'] == true;
    final target = _sessionPosition(s);
    final current = video.value.position;
    final drift = (current - target).abs();

    if (force || drift > const Duration(milliseconds: 2500)) {
      _applyingRemote = true;
      video.seekTo(target).then((_) => _applyingRemote = false);
    }
    if (!driftOnly || force) {
      if (shouldPlay && !video.value.isPlaying) video.play();
      if (!shouldPlay && video.value.isPlaying) video.pause();
    } else {
      // drift pass still corrects play state if they diverged
      if (shouldPlay != video.value.isPlaying) {
        shouldPlay ? video.play() : video.pause();
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _publish({required bool isPlaying, Duration? at}) async {
    final coupleId = _coupleId;
    final video = _video;
    if (coupleId == null || video == null) return;
    final pos = at ?? video.value.position;
    await ref.read(firestoreServiceProvider).updateCinemaPlayback(
          coupleId,
          isPlaying: isPlaying,
          positionMs: pos.inMilliseconds,
        );
  }

  // ── user actions ─────────────────────────────────────────────────────────

  void _togglePlay() {
    final video = _video;
    if (video == null || !video.value.isInitialized || _applyingRemote) return;
    HapticFeedback.lightImpact();
    final playing = video.value.isPlaying;
    if (playing) {
      video.pause();
    } else {
      video.play();
    }
    _publish(isPlaying: !playing);
    _scheduleControlsHide();
    setState(() {});
  }

  void _seekBy(Duration delta) {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    HapticFeedback.lightImpact();
    var target = video.value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > video.value.duration) target = video.value.duration;
    video.seekTo(target);
    _publish(isPlaying: video.value.isPlaying, at: target);
    _scheduleControlsHide();
  }

  void _onScrubEnd(double ms) {
    final video = _video;
    _scrubbing = false;
    if (video == null) return;
    final target = Duration(milliseconds: ms.round());
    video.seekTo(target);
    _publish(isPlaying: video.value.isPlaying, at: target);
    _scheduleControlsHide();
  }

  Future<void> _endMovieNight() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('End movie night?'),
        content: const Text(
          'This closes the theater for both of you.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Keep watching')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('End it')),
        ],
      ),
    );
    if (confirmed != true) return;
    final coupleId = _coupleId;
    if (coupleId != null) {
      await ref.read(firestoreServiceProvider).endCinemaSession(coupleId);
    }
  }

  void _sendReaction(String emoji) {
    final coupleId = _coupleId;
    if (coupleId == null) return;
    HapticFeedback.selectionClick();
    ref.read(firestoreServiceProvider).sendCinemaReaction(coupleId, emoji).ignore();
    // Local echo appears through the reactions stream like the partner's do,
    // but spawn immediately so it feels instant.
    _spawnFloatingReaction(emoji);
  }

  void _spawnFloatingReaction(String emoji) {
    if (!mounted) return;
    final r = _FloatingReaction(
      emoji: emoji,
      x: 0.15 + math.Random().nextDouble() * 0.7,
      id: DateTime.now().microsecondsSinceEpoch,
    );
    setState(() => _floatingReactions.add(r));
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _floatingReactions.remove(r));
    });
  }

  // ── chrome helpers ───────────────────────────────────────────────────────

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_video?.value.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _exitFullscreenChrome();
    }
  }

  void _exitFullscreenChrome() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Follow remote updates.
    ref.listen<AsyncValue<Map<String, dynamic>?>>(cinemaSessionProvider,
        (_, next) {
      final s = next.valueOrNull;
      if (s == null) {
        // Partner ended the movie night.
        if (_fullscreen) _exitFullscreenChrome();
        return;
      }
      if (!_scrubbing) _applySession(s);
    });

    final session =
        ref.watch(cinemaSessionProvider).valueOrNull ?? widget.session;
    final accent = ref.watch(accentColorProvider);
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final partnerFirst = partner?.displayName.split(' ').first ?? 'Partner';

    final watching = (session['watching'] as Map<String, dynamic>?) ?? {};
    final partnerTs = partner == null ? null : watching[partner.uid];
    final partnerHere = partnerTs is Timestamp &&
        DateTime.now().difference(partnerTs.toDate()).inSeconds < 45;

    final video = _video;
    final ready = video != null && video.value.isInitialized;
    final title = (session['title'] as String?)?.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _scheduleControlsHide,
        child: Stack(
          children: [
            // ── video surface ──
            Positioned.fill(
              child: Center(
                child: _initError != null
                    ? _ErrorPane(message: _initError!, onClose: _endMovieNight)
                    : !ready
                        ? const CircularProgressIndicator()
                        : AspectRatio(
                            aspectRatio: video.value.aspectRatio,
                            child: VideoPlayer(video),
                          ),
              ),
            ),

            // ── floating reactions ──
            ..._floatingReactions.map(
              (r) => Positioned(
                left: MediaQuery.of(context).size.width * r.x,
                bottom: 120,
                child: Text(r.emoji, style: const TextStyle(fontSize: 34))
                    .animate(key: ValueKey(r.id))
                    .moveY(begin: 0, end: -260, duration: 2200.ms,
                        curve: Curves.easeOut)
                    .fadeOut(begin: 1, delay: 1200.ms, duration: 1000.ms)
                    .scale(
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1.1, 1.1),
                        duration: 400.ms),
              ),
            ),

            // ── top bar ──
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    right: 16,
                    bottom: 20,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        onPressed: () {
                          if (_fullscreen) {
                            _toggleFullscreen();
                          } else {
                            Navigator.of(context).maybePop();
                          }
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title == null || title.isEmpty
                                  ? 'Movie Night'
                                  : title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: partnerHere
                                        ? const Color(0xFF4CAF7D)
                                        : Colors.white30,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  partnerHere
                                      ? 'Watching with $partnerFirst ♡'
                                      : 'Waiting for $partnerFirst to join…',
                                  style: TextStyle(
                                      color: partnerHere
                                          ? const Color(0xFF9BDDB9)
                                          : Colors.white54,
                                      fontSize: 11.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'End movie night',
                        icon: const Icon(Icons.power_settings_new_rounded,
                            color: Colors.white70),
                        onPressed: _endMovieNight,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── bottom controls ──
            if (ready)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: Container(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 40,
                        bottom: MediaQuery.of(context).padding.bottom + 12,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // reaction bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _reactionEmojis
                                .map((e) => SquishyTap(
                                      onTap: () => _sendReaction(e),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        child: Text(e,
                                            style: const TextStyle(
                                                fontSize: 24)),
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          // scrubber
                          Row(
                            children: [
                              Text(
                                _fmt(_scrubbing
                                    ? Duration(
                                        milliseconds: _scrubValue.round())
                                    : video.value.position),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 3,
                                    activeTrackColor: accent,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: Colors.white,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 14),
                                  ),
                                  child: Slider(
                                    value: (_scrubbing
                                            ? _scrubValue
                                            : video.value.position.inMilliseconds
                                                .toDouble())
                                        .clamp(
                                            0,
                                            video.value.duration.inMilliseconds
                                                .toDouble()),
                                    max: video.value.duration.inMilliseconds
                                        .toDouble()
                                        .clamp(1, double.infinity),
                                    onChangeStart: (v) {
                                      _scrubbing = true;
                                      _scrubValue = v;
                                    },
                                    onChanged: (v) =>
                                        setState(() => _scrubValue = v),
                                    onChangeEnd: _onScrubEnd,
                                  ),
                                ),
                              ),
                              Text(
                                _fmt(video.value.duration),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          // transport
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.replay_10_rounded,
                                    color: Colors.white, size: 30),
                                onPressed: () =>
                                    _seekBy(const Duration(seconds: -10)),
                              ),
                              SquishyTap(
                                onTap: _togglePlay,
                                child: Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [
                                      accent,
                                      AppColors.coral,
                                    ]),
                                    boxShadow: [
                                      BoxShadow(
                                          color:
                                              accent.withValues(alpha: 0.4),
                                          blurRadius: 16),
                                    ],
                                  ),
                                  child: Icon(
                                    video.value.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.forward_10_rounded,
                                    color: Colors.white, size: 30),
                                onPressed: () =>
                                    _seekBy(const Duration(seconds: 10)),
                              ),
                              IconButton(
                                icon: Icon(
                                  _fullscreen
                                      ? Icons.fullscreen_exit_rounded
                                      : Icons.fullscreen_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: _toggleFullscreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatingReaction {
  final String emoji;
  final double x; // 0..1 fraction of screen width
  final int id;
  _FloatingReaction({required this.emoji, required this.x, required this.id});
}

class _ErrorPane extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  const _ErrorPane({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.movie_creation_outlined,
            color: Colors.white38, size: 52),
        const SizedBox(height: 16),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70, fontSize: 14, height: 1.5)),
        const SizedBox(height: 20),
        TextButton(
          onPressed: onClose,
          child: const Text('End movie night',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
