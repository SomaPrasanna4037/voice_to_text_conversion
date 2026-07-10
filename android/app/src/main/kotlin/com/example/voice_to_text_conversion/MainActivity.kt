package com.example.voice_to_text_conversion

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "voice_to_text_conversion/speech_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openSpeechSettings" -> result.success(openSpeechSettings())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Tries, in order:
     *  1. The Google app's voice/language settings (most useful on Android < 12)
     *  2. The system offline speech settings (Android 12+)
     *  3. This app's details page so the user can at least open system settings manually
     *
     * Returns one of: "google", "offline_speech", "app_details", or "unavailable".
     */
    private fun openSpeechSettings(): String {
        // 1) Google app voice/language settings (works on most Android versions)
        try {
            val googleIntent = Intent().apply {
                component = ComponentName(
                    "com.google.android.googlequicksearchbox",
                    "com.google.android.voicesearch.intentapi.VoiceSearchActivity"
                )
                putExtra("lang_pref", "any")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(googleIntent)
            return "google"
        } catch (_: Throwable) {
            // fall through
        }

        // 2) Android 12+ offline speech settings
        try {
            val offline = Intent("com.android.settings.SPEECH_RECOGNITION_SETTINGS").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(offline)
            return "offline_speech"
        } catch (_: ActivityNotFoundException) {
            // fall through
        } catch (_: SecurityException) {
            // fall through
        }

        // 3) Last-resort: app details so the user can open system settings
        try {
            val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.fromParts("package", packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(details)
            return "app_details"
        } catch (_: Throwable) {
            return "unavailable"
        }
    }
}
