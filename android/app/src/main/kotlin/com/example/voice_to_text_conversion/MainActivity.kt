package com.example.voice_to_text_conversion

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.os.Build
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.RecognitionSupportCallback
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "voice_to_text_conversion/speech_settings"
    private val debugChannelName = "voice_to_text_conversion/speech_debug"
    private val logTag = "SpeechDebug"

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

        // Add debug channel for speech recognition support logging
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            debugChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "debugRecognitionSupport" -> debugRecognitionSupport(result)
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Debug method to log RecognitionSupport details directly.
     * Calls onSupportResult which logs the available, installed, and pending
     * on-device languages.
     */
    private fun debugRecognitionSupport(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33) {
            result.success("Debug: API level 33+ required for RecognitionSupport")
            return
        }

        try {
            val context = this
            if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                result.success("Debug: On-device recognition not available")
                return
            }

            val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            val recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)

            recognizer.checkRecognitionSupport(
                recognizerIntent,
                Executors.newSingleThreadExecutor(),
                object : RecognitionSupportCallback {
                    override fun onSupportResult(recognitionSupport: android.speech.RecognitionSupport) {
                        Log.d(logTag, "===== RECOGNITION SUPPORT DEBUG =====")
                        
                        Log.d(logTag, "onDevice=${recognitionSupport.supportedOnDeviceLanguages}")
                        Log.d(logTag, "onDevice count=${recognitionSupport.supportedOnDeviceLanguages?.size ?: 0}")
                        recognitionSupport.supportedOnDeviceLanguages?.forEach { lang ->
                            Log.d(logTag, "  - OnDevice: $lang")
                        }

                        Log.d(logTag, "installed=${recognitionSupport.installedOnDeviceLanguages}")
                        Log.d(logTag, "installed count=${recognitionSupport.installedOnDeviceLanguages?.size ?: 0}")
                        recognitionSupport.installedOnDeviceLanguages?.forEach { lang ->
                            Log.d(logTag, "  - Installed: $lang")
                        }

                        Log.d(logTag, "pending=${recognitionSupport.pendingOnDeviceLanguages}")
                        Log.d(logTag, "pending count=${recognitionSupport.pendingOnDeviceLanguages?.size ?: 0}")
                        recognitionSupport.pendingOnDeviceLanguages?.forEach { lang ->
                            Log.d(logTag, "  - Pending: $lang")
                        }

                        Log.d(logTag, "===== END DEBUG =====")
                        
                        recognizer.destroy()
                        result.success("Debug: Check logcat with tag 'SpeechDebug' for output")
                    }

                    override fun onError(error: Int) {
                        Log.e(logTag, "Error from checkRecognitionSupport: $error")
                        recognizer.destroy()
                        result.error("DEBUG_ERROR", "checkRecognitionSupport error: $error", null)
                    }
                }
            )
        } catch (e: Exception) {
            Log.e(logTag, "Exception during debug", e)
            result.error("DEBUG_EXCEPTION", "Exception: ${e.message}", null)
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
