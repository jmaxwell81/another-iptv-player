package com.example.anotheriptvplayer

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val TV_DETECTION_CHANNEL = "com.another_iptv_player/tv_detection"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_DETECTION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAndroidTV" -> {
                    result.success(isAndroidTV())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isAndroidTV(): Boolean {
        // Method 1: Check for leanback feature (most reliable)
        val hasLeanback = packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        if (hasLeanback) return true

        // Method 2: Check UI mode
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        if (uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
            return true
        }

        // Method 3: Check for touchscreen absence (TV devices typically don't have touchscreens)
        val hasTouchscreen = packageManager.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
        if (!hasTouchscreen) {
            return true
        }

        return false
    }
}
