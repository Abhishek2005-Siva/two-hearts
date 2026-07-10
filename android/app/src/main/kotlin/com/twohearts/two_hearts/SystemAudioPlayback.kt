package com.twohearts.two_hearts

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log

/**
 * Plays raw 16-bit PCM mono chunks as they arrive over the data channel —
 * a live stream, not a file, so this uses AudioTrack directly in
 * MODE_STREAM rather than any file-based player.
 */
class SystemAudioPlayback {
    companion object {
        private const val TAG = "SystemAudioPlayback"
    }

    private var track: AudioTrack? = null

    fun start(sampleRate: Int) {
        stop()
        try {
            val minBuf = AudioTrack.getMinBufferSize(
                sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT
            ).coerceAtLeast(4096)
            track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(minBuf * 4)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
            track?.play()
        } catch (e: Exception) {
            Log.e(TAG, "start playback failed", e)
        }
    }

    fun write(bytes: ByteArray) {
        try {
            track?.write(bytes, 0, bytes.size)
        } catch (_: Exception) {}
    }

    fun stop() {
        try {
            track?.stop()
            track?.release()
        } catch (_: Exception) {}
        track = null
    }
}
