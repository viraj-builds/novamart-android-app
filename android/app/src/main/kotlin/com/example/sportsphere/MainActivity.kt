package com.example.sportsphere

import android.content.Context
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.clevertap.android.geofence.CTGeofenceAPI

// CleverTap needs a FragmentActivity host:
//  - the App Inbox is rendered as a Fragment (CTInboxListViewFragment)
//  - In-App "Header"/"Footer" templates are rendered as Fragments
// https://developer.clevertap.com/docs/flutter-in-app
class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.sportsphere/clevertap_geofence"

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
