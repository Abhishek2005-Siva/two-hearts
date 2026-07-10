import 'package:flutter/services.dart';

/// Thin bridge to the native foreground service that Android 14+ requires
/// while a MediaProjection screen capture is running.
class ScreenCaptureService {
  static const _channel = MethodChannel('two_hearts/screen_capture');

  /// Throws [ScreenCaptureServiceException] if the OS refuses to start the
  /// foreground service (permission/policy change, OEM restriction, etc.) —
  /// callers should stop rather than push ahead into getDisplayMedia(),
  /// which will otherwise fail too but with a far less useful error.
  static Future<void> start() async {
    try {
      await _channel.invokeMethod('start');
    } on PlatformException catch (e) {
      throw ScreenCaptureServiceException(e.message);
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}

class ScreenCaptureServiceException implements Exception {
  final String? message;
  ScreenCaptureServiceException(this.message);
  @override
  String toString() =>
      message ?? 'The screen-sharing service could not be started.';
}
