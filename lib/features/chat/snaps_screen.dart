import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class SnapsScreen extends ConsumerWidget {
  const SnapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapsAsync = ref.watch(snapsProvider);
    final accent = ref.watch(accentColorProvider);

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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: Text('Snaps 📸',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: snapsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.rose)),
                  error: (e, _) => Center(
                      child: Text('Error: $e',
                          style: const TextStyle(
                              color: AppColors.textSecondary))),
                  data: (snaps) {
                    if (snaps.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📸',
                                style: TextStyle(fontSize: 64)),
                            const SizedBox(height: 16),
                            Text('No snaps yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              'Send disappearing photos from the chat ♡',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: snaps.length,
                      itemBuilder: (context, i) => _SnapTile(
                        snap: snaps[i],
                        accent: accent,
                        onTap: () => _showFull(context, snaps[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFull(BuildContext context, MessageModel snap) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Stack(
            children: [
              SizedBox.expand(
                child: CachedNetworkImage(
                  imageUrl: snap.content,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 48,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
              if (snap.snapViewed)
                Positioned(
                  bottom: 48,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Snap viewed 👻',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13)),
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

class _SnapTile extends StatelessWidget {
  final MessageModel snap;
  final Color accent;
  final VoidCallback onTap;

  const _SnapTile({
    required this.snap,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: snap.content,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: AppColors.bgCard),
              errorWidget: (_, _, _) => Container(
                color: AppColors.bgCard,
                child: const Center(
                  child: Text('📸',
                      style: TextStyle(fontSize: 24)),
                ),
              ),
            ),
            if (snap.snapViewed)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: Text('👻',
                      style: TextStyle(fontSize: 20)),
                ),
              ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _timeLabel(snap.sentAt),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
