package com.example.sportsphere

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.ViewGroup
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat
import com.clevertap.android.sdk.CleverTapAPI
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.clevertap.android.geofence.CTGeofenceAPI

// CleverTap needs a FragmentActivity host:
//  - the App Inbox is rendered as a Fragment (CTInboxListViewFragment)
//  - In-App "Header"/"Footer" templates are rendered as Fragments
// https://developer.clevertap.com/docs/flutter-in-app
class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.sportsphere/clevertap_geofence"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        keepInAppsAboveKeyboard()
    }

    // CleverTap header/footer in-apps (native and custom HTML) are Fragments
    // added straight into android.R.id.content, on top of the FlutterView.
    //
    // Flutter draws edge-to-edge and handles the keyboard only inside its own
    // view, so adjustResize never moves those sibling views: a footer in-app
    // with a text box (e.g. an NPS / rating form) ends up under the keyboard
    // and its Submit button can't be reached. Native Android apps don't hit
    // this, which is why the same campaign works there.
    //
    // Every non-Flutter view added to the content frame is lifted by however
    // much of it the keyboard covers, and dropped back when it closes.
    // Full-screen / interstitial / half-interstitial / alert in-apps run in
    // CleverTap's own InAppNotificationActivity and are unaffected.
    private fun keepInAppsAboveKeyboard() {
        val content = findViewById<ViewGroup>(android.R.id.content) ?: return
        content.setOnHierarchyChangeListener(object : ViewGroup.OnHierarchyChangeListener {
            override fun onChildViewAdded(parent: View, child: View) {
                if (containsFlutterView(child)) return
                ViewCompat.setOnApplyWindowInsetsListener(child) { v, insets ->
                    liftAboveKeyboard(v, insets)
                    insets
                }
                // Also animate along with the keyboard instead of jumping.
                ViewCompat.setWindowInsetsAnimationCallback(child,
                    object : WindowInsetsAnimationCompat.Callback(
                        WindowInsetsAnimationCompat.Callback.DISPATCH_MODE_CONTINUE_ON_SUBTREE) {
                        override fun onProgress(
                            insets: WindowInsetsCompat,
                            running: MutableList<WindowInsetsAnimationCompat>
                        ): WindowInsetsCompat {
                            liftAboveKeyboard(child, insets)
                            return insets
                        }
                    })
                ViewCompat.requestApplyInsets(child)
            }

            override fun onChildViewRemoved(parent: View, child: View) {}
        })
    }

    private fun containsFlutterView(view: View): Boolean {
        if (view is FlutterView) return true
        if (view !is ViewGroup) return false
        for (i in 0 until view.childCount) {
            if (containsFlutterView(view.getChildAt(i))) return true
        }
        return false
    }

    private fun liftAboveKeyboard(view: View, insets: WindowInsetsCompat) {
        val parent = view.parent as? View ?: return
        val ime = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
        // view.bottom is the untranslated layout position, so this is stable
        // across repeated calls.
        val covered = view.bottom - (parent.height - ime)
        view.translationY = -covered.coerceAtLeast(0).toFloat()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "triggerGeofenceLocation") {
                    result.success(triggerGeofenceLocation())
                } else {
                    result.notImplemented()
                }
            }
    }

    // Android 12+: a push tapped while this activity is already open arrives
    // here instead of a new activity, so the SDK must be told about the click —
    // otherwise "Notification Clicked" isn't recorded and the Dart
    // push-clicked handler (deep links) never fires.
    // https://developer.clevertap.com/docs/android-12-updates
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            CleverTapAPI.getDefaultInstance(applicationContext)?.pushNotificationClickedEvent(intent.extras)
        }
    }

    // Called from Dart once the runtime location permissions have been granted.
    //
    // Application.onCreate() runs before Dart requests those permissions, so on a
    // first launch the geofence SDK is initialized without them and background
    // updates are never started. Starting them here means the user does not have
    // to restart the app for geofencing to begin working.
    private fun triggerGeofenceLocation(): Boolean {
        return try {
            CTGeofenceAPI.getInstance(applicationContext).apply {
                initBackgroundLocationUpdates()
                triggerLocation()
            }
            true
        } catch (t: Throwable) {
            Log.e("MainActivity", "Failed to trigger geofence location", t)
            false
        }
    }
}
