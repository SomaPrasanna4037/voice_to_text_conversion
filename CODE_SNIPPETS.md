# Code Snippets: Speech Debug Implementation

Complete code reference for all changes made.

---

## 1. Kotlin Native Code (MainActivity.kt)

### Key Imports Added
```kotlin
import android.os.Build
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.RecognitionSupportCallback
import android.util.Log
import java.util.concurrent.Executors
```

### Constants
```kotlin
class MainActivity : FlutterActivity() {
    private val debugChannelName = "voice_to_text_conversion/speech_debug"
    private val logTag = "SpeechDebug"
```

### Method Channel Registration
```kotlin
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    
    // ... existing channel ...
    
    // Add debug channel
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
```

### Debug Method Implementation
```kotlin
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
```

---

## 2. Dart Service Method (speech_service.dart)

### Method to Add to SpeechService Class
```dart
/// Debug method: Calls the native Android code to log RecognitionSupport
/// details directly. Check logcat with tag 'SpeechDebug' for the output.
/// Only works on Android API 33+ with on-device speech recognition available.
Future<String> debugRecognitionSupport() async {
  if (!Platform.isAndroid) {
    return 'Debug: Only available on Android';
  }
  try {
    const channel = MethodChannel('voice_to_text_conversion/speech_debug');
    final result = await channel.invokeMethod<String>('debugRecognitionSupport');
    return result ?? 'Debug: No result';
  } on PlatformException catch (e) {
    return 'Debug error: ${e.message}';
  }
}
```

### Required Import at Top
```dart
import 'package:flutter/services.dart'; // Already imported in most cases
```

---

## 3. Flutter Widget (speech_debug_helper.dart - Complete File)

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'speech_service.dart';

class SpeechDebugButton extends StatefulWidget {
  final void Function(String result)? onDebugResult;

  const SpeechDebugButton({
    Key? key,
    this.onDebugResult,
  }) : super(key: key);

  @override
  State<SpeechDebugButton> createState() => _SpeechDebugButtonState();
}

class _SpeechDebugButtonState extends State<SpeechDebugButton> {
  bool _isDebugging = false;
  String? _debugResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: _isDebugging ? null : _runDebug,
          child: _isDebugging
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Debug Speech Recognition'),
        ),
        if (_debugResult != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _debugResult!,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _runDebug() async {
    setState(() => _isDebugging = true);
    try {
      final speechService = context.read<SpeechService>();
      final result = await speechService.debugRecognitionSupport();
      setState(() => _debugResult = result);
      widget.onDebugResult?.call(result);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debug logged. Check logcat: adb logcat SpeechDebug:* *:S'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() => _debugResult = 'Error: $e');
    } finally {
      setState(() => _isDebugging = false);
    }
  }
}
```

---

## 4. Using the Debug Widget

### Simple Integration
```dart
import 'package:voice_to_text_conversion/services/speech_debug_helper.dart';

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Speech Settings')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ... your existing UI ...
          
          const Divider(),
          const SizedBox(height: 16),
          const Text('Debug Information', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SpeechDebugButton(
            onDebugResult: (result) => print('Debug: $result'),
          ),
        ],
      ),
    ),
  );
}
```

### With Custom Error Handling
```dart
SpeechDebugButton(
  onDebugResult: (result) {
    print('Debug result: $result');
    if (result.contains('Check logcat')) {
      // Successfully called, check terminal logs
    } else if (result.contains('Error')) {
      // Handle error
    }
  },
)
```

---

## 5. Direct Method Call (Without Widget)

```dart
final speechService = Provider.of<SpeechService>(context, listen: false);
try {
  final result = await speechService.debugRecognitionSupport();
  print('Result: $result');
} catch (e) {
  print('Error: $e');
}
```

---

## 6. Expected Logcat Output

```
2024-07-10 14:23:45.123  D/SpeechDebug: ===== RECOGNITION SUPPORT DEBUG =====
2024-07-10 14:23:45.124  D/SpeechDebug: onDevice=[en-US, en-GB, es-ES, fr-FR]
2024-07-10 14:23:45.125  D/SpeechDebug: onDevice count=4
2024-07-10 14:23:45.126  D/SpeechDebug:   - OnDevice: en-US
2024-07-10 14:23:45.126  D/SpeechDebug:   - OnDevice: en-GB
2024-07-10 14:23:45.127  D/SpeechDebug:   - OnDevice: es-ES
2024-07-10 14:23:45.127  D/SpeechDebug:   - OnDevice: fr-FR
2024-07-10 14:23:45.128  D/SpeechDebug: installed=[en-US, en-GB]
2024-07-10 14:23:45.129  D/SpeechDebug: installed count=2
2024-07-10 14:23:45.129  D/SpeechDebug:   - Installed: en-US
2024-07-10 14:23:45.130  D/SpeechDebug:   - Installed: en-GB
2024-07-10 14:23:45.131  D/SpeechDebug: pending=[es-ES, fr-FR]
2024-07-10 14:23:45.132  D/SpeechDebug: pending count=2
2024-07-10 14:23:45.132  D/SpeechDebug:   - Pending: es-ES
2024-07-10 14:23:45.133  D/SpeechDebug:   - Pending: fr-FR
2024-07-10 14:23:45.134  D/SpeechDebug: ===== END DEBUG =====
```

---

## 7. Viewing Logs

```bash
# Best method: filter only SpeechDebug logs
adb logcat SpeechDebug:* *:S

# Alternative: grep from full logcat
adb logcat | grep SpeechDebug

# Alternative: using flutter logs
flutter logs --tag SpeechDebug
```

---

## 8. Complete Integration Example

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:voice_to_text_conversion/services/speech_service.dart';
import 'package:voice_to_text_conversion/services/speech_debug_helper.dart';

class MySettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speech Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Existing language selector
            const Text('Select Language'),
            const SizedBox(height: 12),
            // ... your language dropdown ...
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            
            // Debug section
            const Text(
              'Debug Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'View detailed speech recognition support information',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SpeechDebugButton(
              onDebugResult: (result) {
                // Optional: Log the result or send to analytics
                print('Speech debug: $result');
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Summary Checklist

- ✅ Kotlin imports added
- ✅ Method channel registered in MainActivity
- ✅ `debugRecognitionSupport()` method implemented
- ✅ All three language lists logged (supported, installed, pending)
- ✅ Dart wrapper method in `SpeechService`
- ✅ Flutter widget ready to use
- ✅ Comprehensive documentation provided

All code is production-ready and can be used for debugging language availability on user devices.
