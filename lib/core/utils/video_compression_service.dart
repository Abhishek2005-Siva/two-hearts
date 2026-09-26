import 'dart:io';

import 'package:video_compress/video_compress.dart';

/// Compresses [file] before it goes to Cloudinary — "I'm not able to
/// upload any big videos" was almost certainly Cloudinary's own unsigned-
/// upload size ceiling, which can't be raised from the client. Shrinking
/// the file first is the actual fix, not a workaround: MediumQuality
/// noticeably cuts bitrate/resolution while staying watchable, matching
/// what messaging apps do with shared video by default.
///
/// Best-effort: any compression failure (unsupported codec, out of disk,
/// plugin error) falls back to the original file rather than blocking the
/// upload entirely — "just compress it, don't add restrictions" means
/// compression is an optimization here, never a gate.
Future<File> compressVideoForUpload(File file) async {
  try {
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
    );
    if (info?.file != null && await info!.file!.exists()) {
      return info.file!;
    }
  } catch (_) {
    // Fall through to the original file.
  }
  return file;
}
