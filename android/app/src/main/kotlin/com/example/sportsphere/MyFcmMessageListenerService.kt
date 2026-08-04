package com.example.sportsphere

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.NotificationCompat
import com.clevertap.android.sdk.CleverTapAPI
import com.clevertap.android.sdk.pushnotification.fcm.CTFcmMessageHandler
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Custom FCM listener service that replaces the default CleverTap
 * [com.clevertap.android.sdk.pushnotification.fcm.FcmMessageListenerService].
 *
 * This service is the single entry-point for all incoming Firebase Cloud
 * Messaging (FCM) messages.  It gives you full control:
 *
 *  1. Inspect every message before CleverTap touches it.
 *  2. Handle pushes that are NOT from CleverTap yourself (e.g. your own
 *     backend, a third-party service, etc.).
 *  3. For messages that ARE from CleverTap, delegate to [CTFcmMessageHandler]
 *     so the SDK can render the notification, track impressions, etc.
 *
 * Registered in AndroidManifest.xml with the `com.google.firebase.MESSAGING_EVENT`
 * intent filter, replacing the default CleverTap FCM service entry.
 */
class MyFcmMessageListenerService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "MyFcmListenerService"

        // Channel used exclusively for non-CleverTap (custom) push notifications.
        // CleverTap manages its own channel internally — do NOT use this for CT pushes.
        private const val CUSTOM_CHANNEL_ID   = "novamart_custom_push"
        private const val CUSTOM_CHANNEL_NAME = "NovaMart Notifications"
    }

    /**
     * Called whenever a new FCM message arrives.
     *
     * Detection strategy (per CleverTap docs):
     *  – Extract data into a Bundle
     *  – Call CleverTapAPI.getNotificationInfo(extras).fromCleverTap
     *  – If true  → delegate to CTFcmMessageHandler (SDK ≥ 4.4.0)
     *  – If false → handle with your own custom logic
     */
    override fun onMessageReceived(message: RemoteMessage) {
        Log.d(TAG, "onMessageReceived from: ${message.from}")

        try {
            val extras = Bundle()
            for ((key, value) in message.data) {
                extras.putString(key, value)
            }

            val info = CleverTapAPI.getNotificationInfo(extras)

            if (info.fromCleverTap) {
                // ── CleverTap push ─────────────────────────────────
                Log.d(TAG, "CleverTap push → delegating to CT SDK")
                CTFcmMessageHandler()
                    .createNotification(applicationContext, message)

                // ── Push Impressions (Delivery tracking) ───────────
                CleverTapAPI.getDefaultInstance(applicationContext)
                    ?.pushNotificationViewedEvent(extras)
            } else {
                // ── Your own / third-party push ────────────────────
                Log.d(TAG, "Non-CleverTap push → custom handler")
                handleCustomPush(message)
            }
        } catch (t: Throwable) {
            Log.d(TAG, "Error parsing FCM message", t)
        }
    }

    /**
     * Called when the FCM registration token is refreshed.
     *
     * You MUST forward the new token to CleverTap so it can keep
     * targeting this device. The CT Flutter SDK does this automatically
     * when [com.clevertap.plugin.CleverTapPlugin.onNewToken] is invoked,
     * but since we own the service we call it explicitly here as well.
     */
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "FCM token refreshed: $token")

        // CleverTap SDK will automatically pick up the new token via its
        // internal ComponentFactory / TokenListenerService; no extra call
        // is needed unless you are managing tokens manually.
        //
        // If you ever manage tokens manually, uncomment and adapt:
        // val ct = CleverTapAPI.getDefaultInstance(applicationContext)
        // ct?.pushFcmRegistrationId(token, true)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Handle push messages that did NOT originate from CleverTap.
     *
     * Replace / extend this method with your own notification building logic.
     */
    /**
     * Displays a standard Android notification for messages NOT from CleverTap.
     *
     * Expected payload keys (sent from Firebase Console or your backend):
     *   notification.title  → notification title   (set in Firebase Console UI)
     *   notification.body   → notification body    (set in Firebase Console UI)
     *   data["url"]         → URL to open on tap   (set in "Additional options" → data)
     *
     * If "url" is missing or empty, tapping opens the app's main screen instead.
     */
    private fun handleCustomPush(message: RemoteMessage) {
        // ── 1. Extract content ──────────────────────────────────────────────
        // Firebase Console sets the notification block; data-only senders use data map.
        val title = message.notification?.title ?: message.data["title"] ?: "NovaMart"
        val body  = message.notification?.body  ?: message.data["body"]  ?: ""
        val url   = message.data["url"]  // optional — null if not provided

        Log.d(TAG, "Custom push → title=$title | body=$body | url=$url")

        // ── 2. Build tap intent ─────────────────────────────────────────────
        // If a URL is in the payload → open it in the browser.
        // Otherwise → open the app's launcher activity.
        val tapIntent: Intent = if (!url.isNullOrBlank()) {
            Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
        } else {
            packageManager.getLaunchIntentForPackage(packageName)
                ?: Intent(applicationContext, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                }
        }

        val pendingIntent = PendingIntent.getActivity(
            applicationContext,
            System.currentTimeMillis().toInt(), // unique request code per notification
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── 3. Ensure notification channel exists (Android 8+) ──────────────
        ensureCustomChannel()

        // ── 4. Build and show the notification ──────────────────────────────
        val notification = NotificationCompat.Builder(this, CUSTOM_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)  // your app icon
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body)) // expand long text
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)  // dismiss on tap
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        val notificationManager =
            getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        // Use timestamp as notification ID so multiple pushes don't overwrite each other.
        notificationManager.notify(System.currentTimeMillis().toInt(), notification)

        Log.d(TAG, "Custom notification shown")
    }

    /**
     * Creates the custom notification channel once.
     * Safe to call repeatedly — Android ignores duplicate channel creation.
     * Required on Android 8.0 (API 26) and above.
     */
    private fun ensureCustomChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CUSTOM_CHANNEL_ID,
                CUSTOM_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "General app notifications from NovaMart"
                enableLights(true)
                enableVibration(true)
            }
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
