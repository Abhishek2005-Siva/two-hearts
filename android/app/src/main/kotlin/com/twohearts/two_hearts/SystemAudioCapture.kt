package com.twohearts.two_hearts

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Captures this device's own app/media audio (NOT the mic) so the Movie
 * Night screen-share partner can hear whatever's playing, not just
 * narration. Needs its own independent MediaProjection grant — the
 * WebRTC plugin already holds one for video, but there's no supported way
 * to reach into a third-party plugin and reuse its native instance, so
 * this asks Android for a second one. That means a second "start
 * recording or casting" system prompt, just for audio.
 *
 * Apps that opt out of playback capture (AudioAttributes.ALLOW_CAPTURE_BY_NONE
 * — some DRM/streaming apps do this) simply won't be heard; that's an
 * Android-level restriction on their part, not a bug here.
 */
class SystemAudioCapture(private val activity: Activity) {
    companion object {
        const val REQUEST_CODE = 8802
        private const val TAG = "SystemAudioCapture"
        const val SAMPLE_RATE = 44100
    }

    private var projectionManager: MediaProjectionManager? = null
    private var projection: MediaProjection? = null
    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    @Volatile private var capturing = false
    private var pendingPermissionResult: MethodChannel.Result? = null
    var eventSink: EventChannel.EventSink? = null

    fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        projectionManager = activity.getSystemService(Activity.MEDIA_PROJECTION_SERVICE)
                as MediaProjectionManager
        activity.startActivityForResult(
            projectionManager!!.createScreenCaptureIntent(), REQUEST_CODE
        )
    }

    /** Returns true if this result belonged to us (caller should stop propagating). */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val granted = resultCode == Activity.RESULT_OK && data != null
        if (granted) {
            projection = projectionManager?.getMediaProjection(resultCode, data!!)
            projection?.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    capturing = false
                }
            }, Handler(Looper.getMainLooper()))
        }
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        return true
    }

    @SuppressLint("MissingPermission")
    fun start(result: MethodChannel.Result) {
        val proj = projection
        if (proj == null) {
            result.error("NO_PROJECTION", "Audio capture permission not granted", null)
            return
        }
        if (capturing) {
            result.success(true)
            return
        }
        try {
            val config = AudioPlaybackCaptureConfiguration.Builder(proj)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                .build()
            val format = AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(SAMPLE_RATE)
                .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                .build()
            val minBuf = AudioRecord.getMinBufferSize(
                SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
            ).coerceAtLeast(4096)
            val record = AudioRecord.Builder()
                .setAudioFormat(format)
                .setAudioPlaybackCaptureConfig(config)
                .setBufferSizeInBytes(minBuf * 4)
                .build()
            audioRecord = record
            record.startRecording()
            capturing = true
            val mainHandler = Handler(Looper.getMainLooper())
            captureThread = Thread {
                val buffer = ByteArray(minBuf)
                while (capturing) {
                    val n = record.read(buffer, 0, buffer.size)
                    if (n > 0) {
                        val chunk = buffer.copyOf(n)
                        mainHandler.post { eventSink?.success(chunk) }
                    }
                }
            }.also { it.start() }
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "start capture failed", e)
            result.error("START_FAILED", e.message, null)
        }
    }

    fun stop(result: MethodChannel.Result?) {
        capturing = false
        try {
            captureThread?.join(200)
        } catch (_: Exception) {}
        captureThread = null
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null
        try {
            projection?.stop()
        } catch (_: Exception) {}
        projection = null
        result?.success(true)
    }
}
