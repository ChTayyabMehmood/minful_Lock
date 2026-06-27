package com.mindful.android.services.tracking

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.mindful.android.AppConstants
import com.mindful.android.MainActivity
import com.mindful.android.R
import com.mindful.android.generics.ServiceBinder
import com.mindful.android.helpers.device.NotificationHelper
import com.mindful.android.utils.GrayscaleManager
import com.mindful.android.utils.Utils

class TurkeyModeService : Service() {
    private val TAG = "Mindful.TurkeyModeService"

    private val binder = ServiceBinder(this)
    private var whitelistedApps = setOf<String>()
    private var isSessionBased = false
    private var enableGrayscale = true
    private var sessionDurationSec = 0
    private var sessionEndTime: Long = 0
    private var isTimerRunning = false

    private val timerHandler = Handler(Looper.getMainLooper())
    private val timerTickRunnable = object : Runnable {
        override fun run() {
            val remaining = sessionEndTime - System.currentTimeMillis()
            if (remaining <= 0) {
                Log.d(TAG, "Session timer expired, auto-stopping")
                stopTurkeyMode()
                return
            }
            updateNotificationWithRemainingTime(remaining)
            timerHandler.postDelayed(this, 1000)
        }
    }

    companion object {
        const val ACTION_START_TURKEY = "com.mindful.android.action.START_TURKEY_SERVICE"
        const val ACTION_STOP_TURKEY = "com.mindful.android.action.STOP_TURKEY_SERVICE"
        const val EXTRA_WHITELISTED_APPS = "whitelisted_apps"
        const val EXTRA_IS_SESSION_BASED = "is_session_based"
        const val EXTRA_ENABLE_GRAYSCALE = "enable_grayscale"
        const val EXTRA_SESSION_DURATION_SEC = "session_duration_sec"

        fun isRunning(context: Context): Boolean =
            Utils.isServiceRunning(context, TurkeyModeService::class.java)
    }

    override fun onBind(intent: Intent?): IBinder {
        return if (intent?.action == ServiceBinder.ACTION_BIND_TO_MINDFUL) {
            binder
        } else {
            super.onBind(intent)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_TURKEY -> {
                startTurkeyMode(intent)
                return START_STICKY
            }
            ACTION_STOP_TURKEY -> {
                stopTurkeyMode()
                return START_NOT_STICKY
            }
            ServiceBinder.ACTION_START_MINDFUL_SERVICE -> {
                return START_STICKY
            }
            else -> {
                stopSelf()
                return START_NOT_STICKY
            }
        }
    }

    private fun startTurkeyMode(intent: Intent) {
        whitelistedApps = intent.getStringArrayListExtra(EXTRA_WHITELISTED_APPS)?.toSet() ?: emptySet()
        isSessionBased = intent.getBooleanExtra(EXTRA_IS_SESSION_BASED, false)
        enableGrayscale = intent.getBooleanExtra(EXTRA_ENABLE_GRAYSCALE, true)
        sessionDurationSec = intent.getIntExtra(EXTRA_SESSION_DURATION_SEC, 0)

        Log.d(TAG, "Starting turkey mode. Whitelist: $whitelistedApps, Session: $isSessionBased, Grayscale: $enableGrayscale, Duration: ${sessionDurationSec}s")

        // Enable grayscale if permission granted
        if (enableGrayscale && GrayscaleManager.hasPermission(this)) {
            GrayscaleManager.setEnabled(this, true)
        }

        // Start foreground with notification
        startForeground(
            AppConstants.TURKEY_MODE_SERVICE_NOTIFICATION_ID,
            buildNotification()
        )

        // Start session timer if session-based
        if (isSessionBased && sessionDurationSec > 0) {
            sessionEndTime = System.currentTimeMillis() + (sessionDurationSec * 1000L)
            isTimerRunning = true
            timerHandler.post(timerTickRunnable)
        }
    }

    private fun stopTurkeyMode() {
        Log.d(TAG, "Stopping turkey mode")

        // Stop timer
        isTimerRunning = false
        timerHandler.removeCallbacks(timerTickRunnable)

        // Disable grayscale
        if (enableGrayscale && GrayscaleManager.hasPermission(this)) {
            GrayscaleManager.setEnabled(this, false)
        }

        // Broadcast stopped event so Flutter can react
        val stoppedIntent = Intent(AppConstants.ACTION_TURKEY_MODE_STOPPED)
        stoppedIntent.setPackage(packageName)
        sendBroadcast(stoppedIntent)

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildNotification(timeRemaining: String? = null): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val contentText = if (timeRemaining != null) {
            "Time remaining: $timeRemaining"
        } else if (isSessionBased && sessionDurationSec > 0) {
            "Session active"
        } else {
            "Digital detox mode enabled"
        }

        val bigText = if (timeRemaining != null) {
            "Digital detox active - Time remaining: $timeRemaining\n${whitelistedApps.size} apps whitelisted"
        } else {
            "Digital detox mode enabled. Only whitelisted apps are accessible.\n${whitelistedApps.size} apps whitelisted"
        }

        return NotificationCompat.Builder(this, NotificationHelper.SERVICE_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_mindful_notification)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentTitle("Turkey Mode Active")
            .setContentText(contentText)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setSilent(true)
            .build()
    }

    private fun updateNotificationWithRemainingTime(remainingMs: Long) {
        val remainingSec = remainingMs / 1000
        val hours = remainingSec / 3600
        val mins = (remainingSec % 3600) / 60
        val secs = remainingSec % 60
        val timeStr = String.format("%02d:%02d:%02d", hours, mins, secs)

        val notification = buildNotification(timeStr)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(AppConstants.TURKEY_MODE_SERVICE_NOTIFICATION_ID, notification)
    }

    fun updateWhitelist(apps: Set<String>) {
        whitelistedApps = apps
        Log.d(TAG, "Whitelist updated: $whitelistedApps")
    }

    fun getWhitelistedApps(): Set<String> = whitelistedApps

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "TurkeyModeService destroyed")

        isTimerRunning = false
        timerHandler.removeCallbacks(timerTickRunnable)

        // Ensure grayscale is disabled on service destroy
        if (enableGrayscale && GrayscaleManager.hasPermission(this)) {
            GrayscaleManager.setEnabled(this, false)
        }
    }
}
