import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import 'screen_share_screen.dart';

/// Shown before Movie Night's screen share starts: pick between mirroring
/// the whole phone or a single app. The [ScreenShareTarget] enum lives in
/// [screen_share_screen.dart].
class ShareTargetScreen extends StatelessWidget {
  final String coupleId;
  final String callId;
  final String? partnerName;

  const ShareTargetScreen({
    super.key,
    required this.coupleId,
    required this.callId,
    this.partnerName,
  });

  void _choose(BuildContext context, ScreenShareTarget target) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ScreenShareScreen(
        coupleId: coupleId,
        isSharer: true,
        callId: callId,
        partnerName: partnerName,
        shareTarget: target,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('🖥️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text('What do you want to share?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  "You'll get Android's share prompt next — pick the same "
                  "option there to match.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5),
                ),
                const SizedBox(height: 28),
                _TargetCard(
                  emoji: '📱',
                  title: 'Entire screen',
                  subtitle:
                      'Mirror everything — switch apps and they\'ll see it all',
                  onTap: () => _choose(context, ScreenShareTarget.fullScreen),
                ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05),
                const SizedBox(height: 14),
                _TargetCard(
                  emoji: '🪟',
                  title: 'A specific app',
                  subtitle:
                      'Only that app is visible to them — everything else stays private',
                  onTap: () => _choose(context, ScreenShareTarget.singleApp),
                ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TargetCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgCardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
