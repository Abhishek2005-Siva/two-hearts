import 'package:flutter/services.dart';

/// Thin bridge to the native foreground service that Android 14+ requires
/// while a MediaProjection screen capture is running.
class ScreenCaptureService {
  static const _channel = MethodChannel('two_hearts/screen_capture');

  static Future<void> start() async {
    try {
      await _channel.invokeMethod('start');
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
