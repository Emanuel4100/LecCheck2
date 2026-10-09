package com.leccheck.app

import android.app.ActivityManager
import android.app.PendingIntent
import android.app.usage.UsageStatsManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Device details and settings pages plugins don't cover (Dart only
        // sees the kernel): Settings → Reminders and Settings → Developer.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.leccheck.app/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "info" -> result.success(info())
                    "openSettings" -> {
                        open(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null),
                            ),
                        )
                        result.success(null)
                    }
                    "openNotificationSettings" -> {
                        openNotificationSettings(call.argument<String>("channel"))
                        result.success(null)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        // Asks in a system dialog; the list of apps if that's
                        // missing (some phones remove it).
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        } catch (_: ActivityNotFoundException) {
                            open(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        }
                        result.success(null)
                    }
                    "armedReminders" -> {
                        val ids = call.argument<List<Int>>("ids") ?: emptyList()
                        result.success(ids.filter(::isArmed))
                    }
                    "clearReminderCache" -> {
                        getSharedPreferences(REMINDER_CACHE, MODE_PRIVATE).edit().clear().apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun info(): Map<String, Any?> {
        val power = getSystemService(POWER_SERVICE) as PowerManager
        val details =
            mutableMapOf<String, Any?>(
                "release" to Build.VERSION.RELEASE,
                "sdk" to Build.VERSION.SDK_INT,
                "maker" to Build.MANUFACTURER,
                "model" to Build.MODEL,
                // Battery optimization can delay reminders.
                "batteryOptimized" to !power.isIgnoringBatteryOptimizations(packageName),
                // The update notice: which APK fits this phone.
                "abis" to Build.SUPPORTED_ABIS.toList(),
            )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // "Restricted" background use (Samsung: deep sleeping apps) stops
            // alarms from starting the app, so reminders never appear.
            val activities = getSystemService(ACTIVITY_SERVICE) as ActivityManager
            details["backgroundRestricted"] = activities.isBackgroundRestricted
            val usage = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
            details["standbyBucket"] = usage.appStandbyBucket
        }
        return details
    }

    /// The notification settings of LecCheck, or of one of its channels.
    private fun openNotificationSettings(channel: String?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            open(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", packageName, null),
                ),
            )
            return
        }
        val intent =
            if (channel == null) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            } else {
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, channel)
            }
        open(intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
    }

    /// Whether the system still holds the alarm of reminder [id]. The
    /// notifications plugin lists what it scheduled from its own cache, which
    /// survives a force stop; the system drops the alarms themselves.
    private fun isArmed(id: Int): Boolean {
        val intent = Intent().setClassName(this, REMINDER_RECEIVER)
        return PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) != null
    }

    private fun open(intent: Intent) {
        try {
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", packageName, null),
                ),
            )
        }
    }

    private companion object {
        /// flutter_local_notifications' alarm receiver and the cache where it
        /// keeps what it scheduled.
        const val REMINDER_RECEIVER =
            "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
        const val REMINDER_CACHE = "scheduled_notifications"
    }
}
