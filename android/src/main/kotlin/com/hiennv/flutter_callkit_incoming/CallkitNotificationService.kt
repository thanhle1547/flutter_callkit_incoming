package com.hiennv.flutter_callkit_incoming

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import androidx.core.content.ContextCompat

class CallkitNotificationService : Service() {

    companion object {

        private val ActionForeground = listOf(
            CallkitConstants.ACTION_CALL_START,
            CallkitConstants.ACTION_CALL_INCOMING,
            CallkitConstants.ACTION_CALL_ACCEPT
        )


        fun startServiceWithAction(context: Context, action: String, data: Bundle?) {
            if (action == CallkitConstants.ACTION_CALL_DECLINE) {
                stopService(context)
                return
            }

            val intent = Intent(context, CallkitNotificationService::class.java).apply {
                this.action = action
                putExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA, data)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && intent.action in ActionForeground) {
                data?.let {
                    if(it.getBoolean(CallkitConstants.EXTRA_CALLKIT_CALLING_SHOW, true)) {
                        try {
                            ContextCompat.startForegroundService(context, intent)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }else {
                        context.startService(intent)
                    }
                } ?: run {
                    try {
                        ContextCompat.startForegroundService(context, intent)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, CallkitNotificationService::class.java)
            context.stopService(intent)
        }

    }

    // Get notification manager dynamically to handle plugin lifecycle properly
    private fun getCallkitNotificationManager(): CallkitNotificationManager? {
        return FlutterCallkitIncomingPlugin.getInstance()?.getCallkitNotificationManager()
    }


    override fun onCreate() {
        super.onCreate()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action === CallkitConstants.ACTION_CALL_START) {
            intent.getBundleExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA)
                ?.let {
                    if(it.getBoolean(CallkitConstants.EXTRA_CALLKIT_CALLING_SHOW, true)) {
                        getCallkitNotificationManager()?.createNotificationChanel(it)
                        showOngoingCallNotification(it)
                    }else {
                        stopSelf()
                    }
                }
        }
        if (intent?.action === CallkitConstants.ACTION_CALL_INCOMING) {
            intent.getBundleExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA)
                ?.let {
                    if (it.getBoolean(CallkitConstants.EXTRA_CALLKIT_CALLING_SHOW, true)) {
                        showIncomingCallNotification(it)
                    }else {
                        stopSelf()
                    }
                }
        }
        if (intent?.action === CallkitConstants.ACTION_CALL_ACCEPT) {
            intent.getBundleExtra(CallkitConstants.EXTRA_CALLKIT_INCOMING_DATA)
                ?.let {
                    getCallkitNotificationManager()?.clearIncomingNotification(it, true)
                    if (it.getBoolean(CallkitConstants.EXTRA_CALLKIT_CALLING_SHOW, true)) {
                        showOngoingCallNotification(it)
                    }else {
                        stopSelf()
                    }
                }
        }
        if (intent?.action === CallkitConstants.ACTION_CALL_DECLINE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
        }
        return START_STICKY
    }

    @SuppressLint("MissingPermission")
    private fun showOngoingCallNotification(bundle: Bundle) {

        val callkitNotification =
            getCallkitNotificationManager()?.getOnGoingCallNotification(bundle, false)
        if (callkitNotification != null) {
            val typeCall = bundle.getInt(CallkitConstants.EXTRA_CALLKIT_TYPE, -1)
            startForeground(
                callkitNotification.id,
                callkitNotification.notification,
                typeCall > 0
            )
        }
    }

    private fun showIncomingCallNotification(bundle: Bundle) {
        val callkitNotification =
            getCallkitNotificationManager()?.getIncomingNotification(bundle, true)

        if (callkitNotification != null) {
            val typeCall = bundle.getInt(CallkitConstants.EXTRA_CALLKIT_TYPE, -1)
            startForeground(
                callkitNotification.id,
                callkitNotification.notification,
                typeCall > 0
            )
        }
    }

    private fun startForeground(notificationId: Int, notification: Notification, isVideo: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var mask = ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // On Android 14+ (targetSDK 34+), starting an FGS from the background with
                // 'microphone' or 'camera' types throws a SecurityException if the runtime
                // permissions aren't already granted (e.g., during an incoming push while locked).
                //
                // To prevent crashes, only append mic/camera types dynamically once the call
                // is active and permissions are verified. 'phoneCall' type is used initially
                // as it is exempt for calling apps.
                //
                // E/AndroidRuntime(26358): java.lang.RuntimeException: Unable to start service com.hiennv.flutter_callkit_incoming.CallkitNotificationService@43190c0 with Intent { act=com.hiennv.flutter_callkit_incoming.ACTION_CALL_INCOMING xflg=0x4 cmp=com.vcc.bizflycrmapp/com.hiennv.flutter_callkit_incoming.CallkitNotificationService (has extras) }: java.lang.SecurityException: Starting FGS with type microphone callerApp=ProcessRecord{1769db2 26358:com.vcc.bizflycrmapp/u0a998} targetSDK=36 requires permissions: all of the permissions allOf=true [android.permission.FOREGROUND_SERVICE_MICROPHONE] any of the permissions allOf=false [android.permission.CAPTURE_AUDIO_HOTWORD, android.permission.CAPTURE_AUDIO_OUTPUT, android.permission.CAPTURE_MEDIA_OUTPUT, android.permission.CAPTURE_TUNER_AUDIO_INPUT, android.permission.CAPTURE_VOICE_COMMUNICATION_OUTPUT, android.permission.RECORD_AUDIO]  and the app must be in the eligible state/exemptions to access the foreground only permission
                // E/AndroidRuntime(26358): Caused by: java.lang.SecurityException: Starting FGS with type microphone callerApp=ProcessRecord targetSDK=36 requires permissions: all of the permissions allOf=true [android.permission.FOREGROUND_SERVICE_MICROPHONE] any of the permissions allOf=false [android.permission.CAPTURE_AUDIO_HOTWORD, android.permission.CAPTURE_AUDIO_OUTPUT, android.permission.CAPTURE_MEDIA_OUTPUT, android.permission.CAPTURE_TUNER_AUDIO_INPUT, android.permission.CAPTURE_VOICE_COMMUNICATION_OUTPUT, android.permission.RECORD_AUDIO]  and the app must be in the eligible state/exemptions to access the foreground only permission
                if (isPermissionGranted(Manifest.permission.RECORD_AUDIO)) {
                    mask = mask or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                }
                if (isVideo && isPermissionGranted(Manifest.permission.CAMERA)) {
                    mask = mask or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                }
            }

            try {
                startForeground(notificationId, notification, mask)
            } catch (e: Exception) {
                // the mic/camera type was rejected (e.g. background start without exemption).
                // Showing the call as a plain phoneCall FGS is always preferable to crashing the whole app.
                e.printStackTrace()
                startForeground(
                    notificationId,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
                )
            }
        } else {
            println("About to start foreground notification")
            startForeground(notificationId, notification)
        }
    }

    private fun isPermissionGranted(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    }


    override fun onDestroy() {
        super.onDestroy()
        // Don't destroy the notification manager here as it's shared across the app
        // The plugin will handle cleanup when all engines are detached
    }

    override fun onBind(p0: Intent?): IBinder? {
        return null
    }


    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // Don't kill the FGS. The app might be closed by user but the call is still ongoing
    }
}