package com.leccheck.app

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
        // Device details for Settings → Developer (Dart only sees the kernel).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.leccheck.app/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "info" -> {
                        val power = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(
                            mapOf(
                                "release" to Build.VERSION.RELEASE,
                                "sdk" to Build.VERSION.SDK_INT,
                                "maker" to Build.MANUFACTURER,
                                "model" to Build.MODEL,
                                // Battery optimization can delay reminders.
                                "batteryOptimized" to
                                    !power.isIgnoringBatteryOptimizations(packageName),
                            ),
                        )
                    }
                    "openSettings" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null),
                            ),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
