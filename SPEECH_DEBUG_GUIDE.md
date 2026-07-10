# Speech Recognition Debug Guide

## Overview

This guide explains the native Android logging code added to debug the `RecognitionSupport` callback from the `speech_to_text` plugin. The debug code directly logs the following from the Android native layer:

- **`supportedOnDeviceLanguages`** — Languages the device's recognizer supports on-device
- **`installedOnDeviceLanguages`** — Languages the user has installed locally
- **`pendingOnDeviceLanguages`** — Languages pending download/installation

This mirrors the exact code pattern from the [speech_to_text plugin](https://github.com/csdcorp/speech_to_text/blob/e753bb6e391817637c861478f15f7c1fbde18d55/speech_to_text/android/src/main/kotlin/com/csdcorp/speech_to_text/SpeechToTextPlugin.kt#L384) but with detailed logging in the `onSupportResult()` override.

---

## Files Modified

### 1. `android/app/src/main/kotlin/com/example/voice_to_text_conversion/MainActivity.kt`

**Added:**
- New method channel: `"voice_to_text_conversion/speech_debug"`
- Method: `debugRecognitionSupport(result: MethodChannel.Result)`

**The `debugRecognitionSupport()` method:**
1. Checks API level (requires 33+)
2. Verifies on-device speech recognition is available
3. Creates an on-device `SpeechRecognizer`
4. Calls `checkRecognitionSupport()` with a callback
5. In `onSupportResult()` override, logs:
   ```kotlin
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
   ```

### 2. `lib/services/speech_service.dart`

**Added:**
- Method: `Future<String> debugRecognitionSupport()`
- Calls the native Android method channel
- Returns status message for UI feedback
- Only works on Android (returns early on iOS)

### 3. `lib/services/speech_debug_helper.dart` (NEW FILE)

**Utility widget** `SpeechDebugButton` that:
- Provides a button to trigger the debug method
- Shows a loading indicator while running
- Displays the result message
- Shows a SnackBar with logcat command hint

---

## How to Use

### Option 1: Call Directly from Code

```dart
final speechService = Provider.of<SpeechService>(context, listen: false);
final result = await speechService.debugRecognitionSupport();
print(result); // e.g., "Debug: Check logcat with tag 'SpeechDebug' for output"
```

### Option 2: Use the Debug Widget

```dart
import 'lib/services/speech_debug_helper.dart';

// In your widget build:
SpeechDebugButton(
  onDebugResult: (result) => print('Debug: $result'),
)
```

### Option 3: Manual Platform Channel Call

```dart
import 'package:flutter/services.dart';

const channel = MethodChannel('voice_to_text_conversion/speech_debug');
try {
  final result = await channel.invokeMethod<String>('debugRecognitionSupport');
  print(result);
} on PlatformException catch (e) {
  print('Error: ${e.message}');
}
```

---

## Viewing the Logs

### Using `flutter logs`

```bash
flutter logs --tag SpeechDebug
```

### Using `adb logcat`

```bash
adb logcat SpeechDebug:* *:S
```

The filter `*:S` suppresses all other tags (silent by default except SpeechDebug).

### Grepping for specific patterns

```bash
# Show just the language lists
adb logcat | grep -E "(OnDevice|Installed|Pending):"

# Show debug section header and footer
adb logcat | grep -E "(===== |count=)"
```

---

## Example Log Output

```
2024-07-10 14:23:45.123  1234  5678 D SpeechDebug: ===== RECOGNITION SUPPORT DEBUG =====
2024-07-10 14:23:45.124  1234  5678 D SpeechDebug: onDevice=[en-US, en-GB, es-ES, fr-FR]
2024-07-10 14:23:45.125  1234  5678 D SpeechDebug: onDevice count=4
2024-07-10 14:23:45.126  1234  5678 D SpeechDebug:   - OnDevice: en-US
2024-07-10 14:23:45.126  1234  5678 D SpeechDebug:   - OnDevice: en-GB
2024-07-10 14:23:45.127  1234  5678 D SpeechDebug:   - OnDevice: es-ES
2024-07-10 14:23:45.127  1234  5678 D SpeechDebug:   - OnDevice: fr-FR
2024-07-10 14:23:45.128  1234  5678 D SpeechDebug: installed=[en-US, en-GB]
2024-07-10 14:23:45.129  1234  5678 D SpeechDebug: installed count=2
2024-07-10 14:23:45.129  1234  5678 D SpeechDebug:   - Installed: en-US
2024-07-10 14:23:45.130  1234  5678 D SpeechDebug:   - Installed: en-GB
2024-07-10 14:23:45.131  1234  5678 D SpeechDebug: pending=[es-ES, fr-FR]
2024-07-10 14:23:45.132  1234  5678 D SpeechDebug: pending count=2
2024-07-10 14:23:45.132  1234  5678 D SpeechDebug:   - Pending: es-ES
2024-07-10 14:23:45.133  1234  5678 D SpeechDebug:   - Pending: fr-FR
2024-07-10 14:23:45.134  1234  5678 D SpeechDebug: ===== END DEBUG =====
```

---

## Requirements & Limitations

| Requirement | Details |
|------------|---------|
| **Minimum API Level** | 33 (Android 13+) — `RecognitionSupport` is a new API |
| **Device Feature** | `SpeechRecognizer.isOnDeviceRecognitionAvailable()` must return true |
| **Platform** | Android only (iOS returns early with message) |
| **Permissions** | `RECORD_AUDIO` (already required by speech_to_text plugin) |

### Why API 33+?

The `RecognitionSupport` API and `checkRecognitionSupport()` callback are new in Android 13 (API 33). This allows introspection into which languages are available, installed, and pending without actually starting a recognition session.

---

## Troubleshooting

### No output in logcat?

1. **Check the returned message**: 
   - `"Debug: On-device recognition not available"` → Device doesn't support on-device speech
   - `"Debug: API level 33+ required..."` → Device is too old

2. **Restart adb**:
   ```bash
   adb kill-server
   adb start-server
   flutter logs --tag SpeechDebug
   ```

3. **Check filter syntax**:
   ```bash
   # Bad: only shows SpeechDebug but might not work
   adb logcat SpeechDebug
   
   # Good: explicitly filter SpeechDebug + silence others
   adb logcat SpeechDebug:* *:S
   ```

### App crashes?

- Ensure `RECORD_AUDIO` permission is granted
- Verify the device supports on-device speech recognition
- Check that the method channel name matches exactly: `"voice_to_text_conversion/speech_debug"`

---

## How It Differs from the Plugin

The plugin's `locales()` method (which you already use) calls `checkRecognitionSupport()` but only returns the **supported** on-device languages that match a curated list. This debug code shows:

- **All three lists**: supported, installed, pending
- **Raw language tags**: exactly as the Android framework reports them
- **Immediate feedback**: all logged to logcat in one shot

This is useful for verifying:
- Which languages Android reports as available
- Which ones are actually downloaded on the device
- Which ones are pending (need to be downloaded from the Play Services)

---

## References

- [speech_to_text plugin source](https://github.com/csdcorp/speech_to_text/blob/e753bb6e391817637c861478f15f7c1fbde18d55/speech_to_text/android/src/main/kotlin/com/csdcorp/speech_to_text/SpeechToTextPlugin.kt)
- [Android RecognitionSupport docs](https://developer.android.com/reference/android/speech/RecognitionSupport)
- [SpeechRecognizer.checkRecognitionSupport()](https://developer.android.com/reference/android/speech/SpeechRecognizer#checkRecognitionSupport(android.content.Intent,%20java.util.concurrent.Executor,%20android.speech.RecognitionSupportCallback))
