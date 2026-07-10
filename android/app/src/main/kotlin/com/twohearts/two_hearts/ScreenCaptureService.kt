package com.twohearts.two_hearts

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * A minimal foreground service of type `mediaProjection`. Android 14+ (and
 * our target SDK 36) refuses to create a screen-capture virtual display
 * unless such a service is running, so we start this right before calling
 * getDisplayMedia and stop it when the share ends.
 */
class ScreenCaptureService : Service() {
    companion object {
        const val CHANNEL_ID = "screen_share_channel"
        const val NOTIF_ID = 8801
        const val TAG = "ScreenCaptureService"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        val notification: Notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Sharing your screen")
            .setContentText("Two Hearts is sharing your screen ♡")
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setOngoing(true)
            .build()

        // startForeground() with type mediaProjection can be refused by the
        // OS (permission/policy changes, OEM battery restrictions, a stale
        // notification permission, etc.) — without a catch here, that threw
        // straight up through the framework and crashed the whole app with
        // no visible error, instead of just failing this screen share.
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIF_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
            } else {
                startForeground(NOTIF_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                mgr.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Screen sharing",
                        NotificationManager.IMPORTANCE_LOW
                    )
                )
            }
        }
    }
}
