package com.mindful.android.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.mindful.android.AppConstants
import com.mindful.android.helpers.storage.SharedPrefsHelper
import com.mindful.android.services.tracking.TurkeyModeService
import com.mindful.android.utils.Utils
import java.security.MessageDigest

/**
 * BroadcastReceiver that listens for ADB unlock commands to disable Turkey Mode.
 *
 * Usage from PC:
 *   adb shell am broadcast -a com.mindful.android.action.UNLOCK_TURKEY_MODE \
 *     --es token "your_passphrase" \
 *     -n com.mindful.android/.receivers.AdbUnlockReceiver
 */
class AdbUnlockReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "Mindful.AdbUnlockReceiver"
        const val ACTION_UNLOCK = "com.mindful.android.action.UNLOCK_TURKEY_MODE"
        const val EXTRA_TOKEN = "token"

        // Broadcast result codes
        const val RESULT_UNLOCK_SUCCESS = 1
        const val RESULT_UNLOCK_FAILED = 2
        const val RESULT_INVALID_TOKEN = 3
        const val RESULT_SERVICE_NOT_RUNNING = 4
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_UNLOCK) {
            Log.w(TAG, "Received unexpected action: ${intent.action}")
            return
        }

        val receivedPassphrase = intent.getStringExtra(EXTRA_TOKEN)

        if (receivedPassphrase.isNullOrEmpty()) {
            Log.w(TAG, "Empty passphrase provided")
            sendResult(context, RESULT_INVALID_TOKEN)
            return
        }

        // Check if TurkeyModeService is actually running
        if (!Utils.isServiceRunning(context, TurkeyModeService::class.java)) {
            Log.w(TAG, "Turkey mode service is not running")
            sendResult(context, RESULT_SERVICE_NOT_RUNNING)
            return
        }

        // Read stored hash
        val storedHash = SharedPrefsHelper.getSetUnlockPassphraseHash(context, null)
        if (storedHash.isEmpty()) {
            Log.w(TAG, "No passphrase hash set - defaulting to unlock")
            triggerUnlock(context)
            return
        }

        // Hash the received passphrase and compare
        val receivedHash = MessageDigest.getInstance("SHA-256")
            .digest(receivedPassphrase.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }

        if (receivedHash != storedHash) {
            Log.w(TAG, "Passphrase hash mismatch")
            sendResult(context, RESULT_UNLOCK_FAILED)
            return
        }

        Log.d(TAG, "Passphrase validated, unlocking turkey mode")
        triggerUnlock(context)
    }

    private fun triggerUnlock(context: Context) {
        // Stop the TurkeyModeService
        val stopIntent = Intent(context, TurkeyModeService::class.java).apply {
            action = TurkeyModeService.ACTION_STOP_TURKEY
        }
        context.startService(stopIntent)

        // Also clear restriction manager via broadcast
        val clearIntent = Intent(AppConstants.ACTION_STOP_TURKEY_MODE)
        clearIntent.setPackage(context.packageName)
        context.sendBroadcast(clearIntent)

        Log.d(TAG, "Turkey mode unlock successful")
        sendResult(context, RESULT_UNLOCK_SUCCESS)
    }

    private fun sendResult(context: Context, resultCode: Int) {
        val resultIntent = Intent("com.mindful.android.action.TURKEY_MODE_UNLOCK_RESULT")
        resultIntent.setPackage(context.packageName)
        resultIntent.putExtra("result_code", resultCode)
        context.sendBroadcast(resultIntent)
    }
}
