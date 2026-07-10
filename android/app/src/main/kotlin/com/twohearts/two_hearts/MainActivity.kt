package com.twohearts.two_hearts

import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "two_hearts/screen_capture"
    private val audioCapture by lazy { SystemAudioCapture(this) }
    private val audioPlayback by lazy { SystemAudioPlayback() }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            val intent = Intent(this, ScreenCaptureService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            // startForegroundService() only schedules the service —
                            // it returns before onStartCommand()/startForeground()
                            // has actually run. On Android 14+, requesting the
                            // MediaProjection screen-capture intent before the
                            // foreground service is truly up throws a
                            // SecurityException, so give it a beat to land before
                            // telling Dart it's safe to proceed.
                            Handler(Looper.getMainLooper()).postDelayed({
                                result.success(true)
                            }, 350)
                        } catch (e: Exception) {
                            // Surface this to Dart instead of letting it crash the
                            // app outright — some OEMs/OS versions now refuse to
                            // start a mediaProjection foreground service at all,
                            // and that used to take the whole app down silently.
                            result.error("FGS_START_FAILED", e.message, null)
                        }
                    }
                    "stop" -> {
                        stopService(Intent(this, ScreenCaptureService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // System/app audio capture during screen share — a second,
        // independent MediaProjection grant (see SystemAudioCapture for why).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "two_hearts/system_audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> audioCapture.requestPermission(result)
                    "start" -> audioCapture.start(result)
                    "stop" -> audioCapture.stop(result)
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "two_hearts/system_audio/stream")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioCapture.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    audioCapture.eventSink = null
                }
            })

        // Plays the partner's captured app audio back on this device.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "two_hearts/audio_playback")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val sampleRate = (call.argument<Int>("sampleRate"))
                            ?: SystemAudioCapture.SAMPLE_RATE
                        audioPlayback.start(sampleRate)
                        result.success(true)
                    }
                    "write" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes != null) audioPlayback.write(bytes)
                        result.success(true)
                    }
                    "stop" -> {
                        audioPlayback.stop()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (audioCapture.onActivityResult(requestCode, resultCode, data)) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
