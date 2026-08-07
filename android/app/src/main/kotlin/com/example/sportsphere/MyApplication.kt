package com.example.sportsphere

import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.util.Log
import androidx.core.content.ContextCompat
import com.clevertap.android.sdk.ActivityLifecycleCallback
import com.clevertap.android.sdk.CleverTapAPI
import com.clevertap.android.geofence.CTGeofenceAPI
import com.clevertap.android.geofence.CTGeofenceSettings
import com.clevertap.android.geofence.interfaces.CTGeofenceEventsListener
import com.clevertap.android.geofence.interfaces.CTLocationUpdatesListener
import org.json.JSONObject

class MyApplication : com.clevertap.android.sdk.Application() {

    companion object {
        private const val TAG = "MyApplication"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Application.onCreate")
        ActivityLifecycleCallback.register(this)

        val cleverTapAPI = CleverTapAPI.getDefaultInstance(applicationContext)
        CleverTapAPI.setDebugLevel(CleverTapAPI.LogLevel.VERBOSE)

        if (cleverTapAPI != null) {
            initCleverTapGeofence(cleverTapAPI)
        } else {
            Log.e(TAG, "Unable to initialize CleverTap Geofence: default CleverTap instance is null")
        }
    }

    private fun initCleverTapGeofence(cleverTapAPI: CleverTapAPI) {
        val geofenceSettings = CTGeofenceSettings.Builder()
            .enableBackgroundLocationUpdates(true)
            .setLocationAccuracy(CTGeofenceSettings.ACCURACY_HIGH)
            .setLocationFetchMode(CTGeofenceSettings.FETCH_CURRENT_LOCATION_PERIODIC)
            .build()

        CTGeofenceAPI.getInstance(applicationContext).apply {
            init(geofenceSettings, cleverTapAPI)

            setOnGeofenceApiInitializedListener(object : CTGeofenceAPI.OnGeofenceApiInitializedListener {
                override fun OnGeofenceApiInitialized() {
                    Log.d(TAG, "CleverTap Geofence API initialized")
                    if (!hasLocationPermissions()) {
                        Log.w(TAG, "Missing location permissions for CleverTap geofence init")
                        return
                    }
                    try {
                        triggerLocation()
                        Log.d(TAG, "Triggered location after geofence init")
                    } catch (t: Throwable) {
                        Log.e(TAG, "Failed to trigger location after geofence init", t)
                    }
                }
            })

            if (!hasLocationPermissions()) {
                Log.w(TAG, "Missing location permissions before starting geofence location updates")
            } else {
                try {
                    initBackgroundLocationUpdates()
                    Log.d(TAG, "CleverTap Geofence background location updates started")
                } catch (t: Throwable) {
                    Log.e(TAG, "Failed to start background location updates", t)
                }

                Log.d(TAG, "Triggering initial CleverTap geofence location update")
                try {
                    triggerLocation()
                } catch (t: Throwable) {
                    Log.e(TAG, "Failed to trigger initial geofence location", t)
                }
            }

            setCtGeofenceEventsListener(object : CTGeofenceEventsListener {
                override fun onGeofenceEnteredEvent(jsonObject: JSONObject) {
                    Log.d(TAG, "CleverTap Geofence entered: $jsonObject")
                    try {
                        val eventProps = mapOf(
                            "geofence" to jsonObject.toString(),
                            "eventType" to "entered"
                        )
                        cleverTapAPI.pushEvent("Geofence Entered", eventProps)
                        Log.d(TAG, "Pushed CleverTap event Geofence Entered")
                    } catch (t: Throwable) {
                        Log.e(TAG, "Failed to push CleverTap Geofence Entered event", t)
                    }
                }

                override fun onGeofenceExitedEvent(jsonObject: JSONObject) {
                    Log.d(TAG, "CleverTap Geofence exited: $jsonObject")
                    try {
                        val eventProps = mapOf(
                            "geofence" to jsonObject.toString(),
                            "eventType" to "exited"
                        )
                        cleverTapAPI.pushEvent("Geofence Exited", eventProps)
                        Log.d(TAG, "Pushed CleverTap event Geofence Exited")
                    } catch (t: Throwable) {
                        Log.e(TAG, "Failed to push CleverTap Geofence Exited event", t)
                    }
                }
            })

            setCtLocationUpdatesListener(object : CTLocationUpdatesListener {
                override fun onLocationUpdates(location: Location) {
                    Log.d(TAG, "CleverTap Geofence location update: ${location.latitude}, ${location.longitude}")

                    if (!hasLocationPermissions()) {
                        Log.w(TAG, "Received location update but missing required permissions")
                        return
                    }

                    try {
                        val profileUpdates = mapOf<String, Any>(
                            "Latitude" to location.latitude,
                            "Longitude" to location.longitude,
                        )
                        cleverTapAPI.pushProfile(profileUpdates)
                        Log.d(TAG, "CleverTap profile location pushed: ${location.latitude}, ${location.longitude}")
                    } catch (t: Throwable) {
                        Log.e(TAG, "Failed to push CleverTap profile location", t)
                    }

                    try {
                        val eventProperties = mapOf<String, Any>(
                            "Latitude" to location.latitude,
                            "Longitude" to location.longitude,
                        )
                        cleverTapAPI.pushEvent("Geofence Location Update", eventProperties)
                        Log.d(TAG, "CleverTap Geofence Location Update event pushed")
                    } catch (t: Throwable) {
                        Log.e(TAG, "Failed to push CleverTap Geofence Location Update event", t)
                    }
                }
            })
        }
    }

    private fun hasLocationPermissions(): Boolean {
        val fine = ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.ACCESS_FINE_LOCATION)
        val background = ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        return fine == PackageManager.PERMISSION_GRANTED && background == PackageManager.PERMISSION_GRANTED
    }
}
