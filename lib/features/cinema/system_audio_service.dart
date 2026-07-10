import 'dart:async';

import 'package:flutter/services.dart';

/// Captures this device's own app/media audio (not the mic) via a second,
/// independent MediaProjection grant — Android's screen-cast permission
/// can't be shared across the WebRTC plugin boundary, so this asks for
/// its own. Streams raw 16-bit PCM mono @44.1kHz chunks as they arrive.
class SystemAudioCapture {
  SystemAudioCapture._();

  static const _channel = MethodChannel('two_hearts/system_audio');
  static const _events = EventChannel('two_hearts/system_audio/stream');
  static const sampleRate = 44100;

  static Future<bool> requestPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

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

  static Stream<Uint8List> get chunks =>
      _events.receiveBroadcastStream().map((e) => e as Uint8List);
}

/// Plays raw PCM chunks received from the partner in near-real-time
/// through a native AudioTrack — a live stream, not a file.
class SystemAudioPlayback {
  SystemAudioPlayback._();

  static const _channel = MethodChannel('two_hearts/audio_playback');

  static Future<void> start({int sampleRate = SystemAudioCapture.sampleRate}) async {
    try {
      await _channel.invokeMethod('start', {'sampleRate': sampleRate});
    } catch (_) {}
  }

  static Future<void> write(Uint8List bytes) async {
    try {
      await _channel.invokeMethod('write', {'bytes': bytes});
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
