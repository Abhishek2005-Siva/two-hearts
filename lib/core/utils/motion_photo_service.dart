import 'package:flutter/foundation.dart';

/// Best-effort detection/extraction of Android's "Motion Photo" format: a
/// still JPEG with a few seconds of MP4 video appended directly after its
/// real end-of-image marker. Pixel/Samsung/etc. camera apps write these;
/// there's no official public spec, but the format is well understood from
/// reverse-engineering (Google's own "Motion Photo Reader" samples and
/// several open-source extractors all use the same technique this does:
/// walk the JPEG's real marker structure to find its true EOI, then check
/// whether an MP4 box follows it).
///
/// image_picker only preserves these bytes untouched when picked with no
/// maxWidth/maxHeight/imageQuality — any of those trigger a decode+re-encode
/// that would silently strip the trailing video data, which is why the
/// photo pick paths that call this must NOT pass those params (the still
/// frame gets compressed separately afterward, see
/// [compressImageBytesForUpload]).
///
/// Unverified on a real device/motion-photo file in this sandbox (no
/// emulator or phone attached) — worst case this simply finds nothing and
/// the photo uploads exactly as it did before.
Future<Uint8List?> extractMotionPhotoVideo(Uint8List bytes) {
  return compute(_extract, bytes);
}

Uint8List? _extract(Uint8List bytes) {
  final eoi = _findJpegEoi(bytes);
  // Require a meaningful amount of trailing data — a few stray bytes after
  // EOI (some encoders pad slightly) isn't a motion video.
  if (eoi == null || eoi >= bytes.length - 100) return null;
  final tail = bytes.sublist(eoi);
  if (tail.length < 12) return null;
  // MP4/MOV is a sequence of length-prefixed "boxes": a 4-byte size then a
  // 4-byte type. A real appended clip starts with an `ftyp` box.
  final boxType = String.fromCharCodes(tail.sublist(4, 8));
  if (boxType != 'ftyp') return null;
  return tail;
}

/// Walks real JPEG marker-segment structure (skipping APPn/EXIF/XMP/DHT/DQT
/// segment payloads by their declared length, and correctly stepping over
/// byte-stuffed 0xFF00 and restart markers inside entropy-coded scan data)
/// to find the position right after the image's genuine End-Of-Image
/// marker. A naive "search for the last 0xFFD9 byte pair" would instead
/// often land inside the appended video's own binary data, since an
/// arbitrary MP4 payload can easily contain that byte pair by coincidence.
int? _findJpegEoi(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
  var i = 2;
  while (i < bytes.length - 1) {
    if (bytes[i] != 0xFF) return null;
    final marker = bytes[i + 1];
    i += 2;
    if (marker == 0xD9) return i; // EOI
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      continue; // standalone marker, no payload
    }
    if (marker == 0xDA) {
      // SOS: length-prefixed header, then entropy-coded scan data until the
      // next real marker.
      if (i + 2 > bytes.length) return null;
      final segLen = (bytes[i] << 8) | bytes[i + 1];
      i += segLen;
      while (i < bytes.length - 1) {
        if (bytes[i] == 0xFF) {
          final next = bytes[i + 1];
          if (next == 0x00 || (next >= 0xD0 && next <= 0xD7)) {
            i += 2; // stuffed byte or restart marker — still scan data
            continue;
          }
          break; // a real marker follows; let the outer loop handle it
        }
        i++;
      }
      continue;
    }
    // Any other length-prefixed segment (APPn, DQT, DHT, SOFn, DRI, COM…).
    if (i + 2 > bytes.length) return null;
    final segLen = (bytes[i] << 8) | bytes[i + 1];
    i += segLen;
  }
  return null;
}
