package com.mindful.android.utils

import android.content.Context
import android.content.pm.PackageManager
import android.provider.Settings
import android.util.Log

/**
 * Manager for toggling system grayscale (monochromacy) mode.
 * Requires WRITE_SECURE_SETTINGS permission (granted via ADB or Shizuku).
 *
 * ADB grant command:
 * adb shell pm grant com.mindful.android android.permission.WRITE_SECURE_SETTINGS
 */
object GrayscaleManager {
    private const val TAG = "Mindful.GrayscaleManager"
    private const val KEY_DALTONIZER_ENABLED = "accessibility_display_daltonizer_enabled"
    private const val KEY_DALTONIZER_MODE = "accessibility_display_daltonizer"
    private const val MODE_MONOCHROMACY = 0
    private const val MODE_DISABLED = -1

    /**
     * Checks if the app has the required WRITE_SECURE_SETTINGS permission.
     */
    fun hasPermission(context: Context): Boolean {
        return context.checkCallingOrSelfPermission(
            "android.permission.WRITE_SECURE_SETTINGS"
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Checks if grayscale mode is currently enabled.
     */
    fun isEnabled(context: Context): Boolean {
        return try {
            val resolver = context.contentResolver
            val enabled = Settings.Secure.getInt(resolver, KEY_DALTONIZER_ENABLED, 0)
            val mode = Settings.Secure.getInt(resolver, KEY_DALTONIZER_MODE, MODE_DISABLED)
            enabled == 1 && mode == MODE_MONOCHROMACY
        } catch (e: Exception) {
            Log.e(TAG, "Error checking grayscale state", e)
            false
        }
    }

    /**
     * Enables or disables grayscale mode.
     * Requires WRITE_SECURE_SETTINGS permission.
     * Returns true if the operation was successful.
     */
    fun setEnabled(context: Context, enabled: Boolean): Boolean {
        if (!hasPermission(context)) {
            Log.w(TAG, "WRITE_SECURE_SETTINGS permission not granted")
            return false
        }

        return try {
            val resolver = context.contentResolver
            Settings.Secure.putInt(
                resolver,
                KEY_DALTONIZER_ENABLED,
                if (enabled) 1 else 0
            )
            Settings.Secure.putInt(
                resolver,
                KEY_DALTONIZER_MODE,
                if (enabled) MODE_MONOCHROMACY else MODE_DISABLED
            )
            Log.d(TAG, "Grayscale ${if (enabled) "enabled" else "disabled"}")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error setting grayscale state", e)
            false
        }
    }

    /**
     * Toggles grayscale and returns the new state.
     */
    fun toggle(context: Context): Boolean {
        val newState = !isEnabled(context)
        setEnabled(context, newState)
        return newState
    }
}
