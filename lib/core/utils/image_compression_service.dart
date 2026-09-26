import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Every other upload path in this app compresses on pick (avatar, photo
/// booth, memories from the picker, letters — see CLAUDE.md) via
/// ImagePicker's own maxWidth/imageQuality params. A photo/video shared in
/// from another app has no picker step to hook that into — it arrives as
/// an arbitrary file already on disk — so this does the same resize
/// (max 1920px long edge) + re-encode (JPEG 85) after the fact instead.
///
/// Runs on a background isolate via [compute] — decode/resize/encode is
/// real CPU work, and doing it on the main thread would jank the UI while
/// a multi-select share batch processes several of these at once.
Future<Uint8List> compressImageBytesForUpload(Uint8List bytes) {
  return compute(_resizeAndEncode, bytes);
}

Uint8List _resizeAndEncode(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  // img.copyResize bakes EXIF orientation internally (rotates the actual
  // pixels to match how the photo is supposed to look), but only when it
  // runs — a photo that didn't need resizing skipped that step entirely
  // and got re-encoded with its raw, un-rotated sensor pixels, so portrait
  // photos came out sideways. Baking orientation unconditionally first
  // fixes that regardless of whether a resize happens afterward.
  final upright = img.bakeOrientation(decoded);
  final needsResize = upright.width > 1920 || upright.height > 1920;
  final resized = needsResize
      ? img.copyResize(
          upright,
          width: upright.width >= upright.height ? 1920 : null,
          height: upright.height > upright.width ? 1920 : null,
        )
      : upright;
  return img.encodeJpg(resized, quality: 85);
}
