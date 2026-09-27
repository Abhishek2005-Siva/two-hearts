package com.twohearts.two_hearts

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationManagerCompat

/**
 * Grants this app access to Android's system MediaSession list — play/
 * pause/skip/track-info for whatever's playing in another app (Spotify),
 * the same OS-level mechanism Bluetooth headset buttons, car head units,
 * and Android Auto already use. No Spotify API, OAuth, or developer
 * account involved: Spotify (like any well-behaved Android media app)
 * exposes this through the platform itself.
 *
 * Android bundles "can see active media sessions" under the same
 * permission as "can read notifications" — there is no narrower
 * permission just for the former — which is why this must be a
 * [NotificationListenerService] even though nothing here ever reads a
 * notification's actual content.
 */
class SpotifyListenerService : NotificationListenerService() {
    companion object {
        const val SPOTIFY_PACKAGE = "com.spotify.music"

        fun isEnabled(context: Context): Boolean =
            NotificationManagerCompat.getEnabledListenerPackages(context)
                .contains(context.packageName)

        fun openSettings(context: Context) {
            context.startActivity(
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }

        /**
         * Spotify's active [MediaController], or null if this app isn't
         * enabled as a notification listener yet, or Spotify has no active
         * media session right now (not open, or hasn't played anything
         * since it last launched).
         */
        fun spotifyController(context: Context): MediaController? {
            if (!isEnabled(context)) return null
            val manager = context.getSystemService(Context.MEDIA_SESSION_SERVICE)
                as MediaSessionManager
            val component = ComponentName(context, SpotifyListenerService::class.java)
            return try {
                manager.getActiveSessions(component)
                    .firstOrNull { it.packageName == SPOTIFY_PACKAGE }
            } catch (e: SecurityException) {
                // Thrown if the listener permission was revoked between the
                // isEnabled() check above and this call (e.g. the user just
                // turned it off in Settings) — treat exactly like "no
                // session" rather than crashing.
                null
            }
        }
    }

    // Required overrides to be a bindable NotificationListenerService at
    // all — intentionally empty, this never reads notification content.
    override fun onNotificationPosted(sbn: StatusBarNotification) {}
    override fun onNotificationRemoved(sbn: StatusBarNotification) {}
}
