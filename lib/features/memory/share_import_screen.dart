import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uuid/uuid.dart';

import '../../core/delight/delight.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/cloudinary_service.dart';
import '../../core/utils/image_compression_service.dart';
import '../../core/utils/motion_photo_service.dart';

/// Confirms and adds photos/videos shared into the app from elsewhere
/// (gallery, Files, another app's share sheet) straight into Memories.
/// Reached via [pendingSharedMediaProvider], populated by the
/// receive_sharing_intent listeners wired up in main.dart — see there for
/// why this is a dedicated screen rather than a dialog fired from
/// wherever the app happens to be.
class ShareImportScreen extends ConsumerStatefulWidget {
  const ShareImportScreen({super.key});

  @override
  ConsumerState<ShareImportScreen> createState() => _ShareImportScreenState();
}

class _ShareImportScreenState extends ConsumerState<ShareImportScreen> {
  bool _uploading = false;
  int _uploadDone = 0;

  Future<void> _addAll(List<SharedMediaFile> files) async {
    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null || files.isEmpty) return;
    setState(() {
      _uploading = true;
      _uploadDone = 0;
    });
    final firestoreService = ref.read(firestoreServiceProvider);
    final uploaderUid = authUser.uid;

    final errors = <String>[];
    var photoCount = 0;
    var videoCount = 0;
    // Same concurrent-upload pattern as the Memory Wall's own picker —
    // each item lands as soon as its own upload finishes rather than
    // queuing behind the others.
    await Future.wait(files.map((file) async {
      try {
        final isVideo = file.type == SharedMediaType.video;
        final id = const Uuid().v4();
        String? motionVideoUrl;
        String url;
        if (isVideo) {
          url = await CloudinaryService.uploadVideo(
            File(file.path),
            folder: 'two_hearts/$coupleId',
          );
        } else {
          final rawBytes = await File(file.path).readAsBytes();
          // Shared-in files arrive as the original, un-recompressed bytes,
          // so a Motion Photo's trailing video data is still intact here —
          // check for it before compressing the still (which re-encodes the
          // JPEG and would destroy it).
          final motionBytes = await extractMotionPhotoVideo(rawBytes);
          url = await CloudinaryService.uploadImage(
            await compressImageBytesForUpload(rawBytes),
            folder: 'two_hearts/$coupleId',
          );
          if (motionBytes != null) {
            final dir = await getTemporaryDirectory();
            final tmp = File('${dir.path}/${const Uuid().v4()}.mp4');
            await tmp.writeAsBytes(motionBytes);
            motionVideoUrl = await CloudinaryService.uploadVideo(tmp, folder: 'two_hearts/$coupleId');
            await tmp.delete().catchError((_) => tmp);
          }
        }
        await firestoreService.addMemory(
          coupleId,
          MemoryModel(
            id: id,
            uploaderUid: uploaderUid,
            imageUrl: url,
            motionVideoUrl: motionVideoUrl,
            createdAt: DateTime.now(),
            isVideo: isVideo,
          ),
        );
        if (isVideo) {
          videoCount++;
        } else {
          photoCount++;
        }
      } catch (e) {
        errors.add(e.toString());
      } finally {
        if (mounted) setState(() => _uploadDone++);
      }
    }));

    firestoreService.notifyBulkMemoryUpload(coupleId, photos: photoCount, videos: videoCount).ignore();

    if (mounted) {
      if (errors.isEmpty) {
        DelightHaptics.thud();
        FloatingStickers.burst(context, stickers: const ['🌸', '✨', '📸'], count: 7);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errors.length == files.length
                ? "Couldn't add: ${errors.first}"
                : "${errors.length} of ${files.length} didn't add: ${errors.first}"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }

    ref.read(pendingSharedMediaProvider.notifier).state = [];
    ReceiveSharingIntent.instance.reset();
    if (mounted) {
      if (errors.isEmpty) {
        context.go('/memory');
      } else {
        setState(() => _uploading = false);
      }
    }
  }

  void _dismiss() {
    ref.read(pendingSharedMediaProvider.notifier).state = [];
    ReceiveSharingIntent.instance.reset();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/memory');
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(pendingSharedMediaProvider);

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
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                      onPressed: _uploading ? null : _dismiss,
                    ),
                    Expanded(
                      child: Text(
                          files.length == 1
                              ? 'Add to Memories?'
                              : 'Add ${files.length} to Memories?',
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(fontSize: 19)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: files.isEmpty
                    ? const Center(
                        child: Text('Nothing to add',
                            style: TextStyle(color: AppColors.textMuted)),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: files.length,
                        itemBuilder: (context, i) {
                          final file = files[i];
                          final isVideo = file.type == SharedMediaType.video;
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                isVideo
                                    ? Container(
                                        color: AppColors.bgCard,
                                        child: const Center(
                                          child: Icon(Icons.videocam_rounded,
                                              color: AppColors.textMuted, size: 32),
                                        ),
                                      )
                                    : Image.file(File(file.path), fit: BoxFit.cover),
                                if (isVideo)
                                  const Positioned(
                                    bottom: 6,
                                    right: 6,
                                    child: Icon(Icons.play_circle_fill_rounded,
                                        color: Colors.white70, size: 20),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (_uploading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: files.isEmpty ? null : _uploadDone / files.length,
                      minHeight: 6,
                      backgroundColor: AppColors.bgCardLight,
                      valueColor: const AlwaysStoppedAnimation(AppColors.rose),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: GradientButton(
                  label: _uploading
                      ? 'Adding $_uploadDone/${files.length}…'
                      : 'Add to Memories',
                  cuteStickers: const ['📸', '✨'],
                  onTap: (_uploading || files.isEmpty) ? null : () => _addAll(files),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
