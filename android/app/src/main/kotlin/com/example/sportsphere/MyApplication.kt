package com.example.sportsphere

import android.location.Location
import android.util.Log
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
                }
            })

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

            setCtGeofenceEventsListener(object : CTGeofenceEventsListener {
                override fun onGeofenceEnteredEvent(jsonObject: JSONObject) {
                    Log.d(TAG, "CleverTap Geofence entered: $jsonObject")
                    cleverTapAPI.pushEvent("Geofence Entered")
                }

                override fun onGeofenceExitedEvent(jsonObject: JSONObject) {
                    Log.d(TAG, "CleverTap Geofence exited: $jsonObject")
                    cleverTapAPI.pushEvent("Geofence Exited")
                }
            })

            setCtLocationUpdatesListener(object : CTLocationUpdatesListener {
                override fun onLocationUpdates(location: Location) {
                    Log.d(TAG, "CleverTap Geofence location update: ${location.latitude}, ${location.longitude}")
                    try {
                        cleverTapAPI.setLocation(location)
                        Log.d(TAG, "CleverTap profile location set: ${location.latitude}, ${location.longitude}")
                    } catch (t: Throwable) {
                        Log.e(TAG, "Failed to update CleverTap profile location", t)
                    }
                }
            })
        }
    }
}
