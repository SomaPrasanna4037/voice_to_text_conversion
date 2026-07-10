# Speech-to-Text Recognition Debug System

## 📋 Overview

Complete native debugging system for the `speech_to_text` Flutter plugin. Logs detailed information about which speech recognition languages are **supported**, **installed**, and **pending** on the device's Android operating system.

This directly inspects the `RecognitionSupport` API from the native Android layer and logs the results to logcat with the tag `SpeechDebug`.

---

## 🎯 What It Does

When you call the debug function, it:

1. **Creates** an on-device speech recognizer (Android 13+)
2. **Calls** `checkRecognitionSupport()` callback
3. **Overrides** `onSupportResult()` to log three language lists:
   - **`supportedOnDeviceLanguages`** — What languages the device can recognize
   - **`installedOnDeviceLanguages`** — What's downloaded and ready to use offline
   - **`pendingOnDeviceLanguages`** — What's currently downloading
4. **Logs** each language individually for easy reading
5. **Returns** a status message to your Flutter code

---

## 📦 Implementation Details

### Files Modified

| File | Change | Lines |
|------|--------|-------|
| `android/app/src/main/.../MainActivity.kt` | Native debug implementation | ~70 |
| `lib/services/speech_service.dart` | Dart wrapper method | ~13 |

### Files Created

| File | Purpose |
|------|---------|
| `lib/services/speech_debug_helper.dart` | Ready-to-use Flutter widget |
| `SPEECH_DEBUG_GUIDE.md` | Technical documentation |
| `INTEGRATION_EXAMPLE.md` | Integration patterns |
| `QUICK_START_DEBUG.md` | 30-second quick start |
| `CODE_SNIPPETS.md` | Complete code reference |
| `DEBUG_IMPLEMENTATION_SUMMARY.md` | Architecture overview |

---

## 🚀 Quick Start (30 Seconds)

### 1. Add Widget
```dart
import 'package:voice_to_text_conversion/services/speech_debug_helper.dart';

SpeechDebugButton()  // Add to your UI
```

### 2. Tap Button
Run app and tap "Debug Speech Recognition"

### 3. View Logs
```bash
adb logcat SpeechDebug:* *:S
```

### 4. Read Output
```
===== RECOGNITION SUPPORT DEBUG =====
onDevice=[en-US, en-GB, ...]
installed=[en-US, ...]
pending=[]
===== END DEBUG =====
```

---

## 📚 Documentation Files

| Document | Use For |
|----------|---------|
| **QUICK_START_DEBUG.md** | Get running in 30 seconds |
| **SPEECH_DEBUG_GUIDE.md** | Complete technical guide |
| **INTEGRATION_EXAMPLE.md** | Integrating into your UI |
| **CODE_SNIPPETS.md** | Copy-paste code references |
| **DEBUG_IMPLEMENTATION_SUMMARY.md** | Architecture & overview |

---

## 🎮 Usage Methods

### Method 1: Use the Widget (Easiest)
```dart
import 'package:voice_to_text_conversion/services/speech_debug_helper.dart';

// In your build:
SpeechDebugButton(
  onDebugResult: (result) => print('Debug: $result'),
)
```

### Method 2: Direct Service Call
```dart
final speechService = context.read<SpeechService>();
final result = await speechService.debugRecognitionSupport();
print(result);
```

### Method 3: Manual Channel
```dart
const channel = MethodChannel('voice_to_text_conversion/speech_debug');
final result = await channel.invokeMethod<String>('debugRecognitionSupport');
```

---

## 📖 Understanding the Output

### The Three Language Lists

```
onDevice=[en-US, en-GB, es-ES, fr-FR]     ← Supported by device
installed=[en-US, en-GB]                   ← Downloaded and ready
pending=[es-ES, fr-FR]                     ← Currently downloading
```

| List | Meaning |
|------|---------|
| **onDevice** | Languages this device's recognizer can potentially use |
| **installed** | Languages already downloaded (ready for offline use) |
| **pending** | Languages in progress of downloading |

### Common Scenarios

**✅ All ready for offline use:**
```
onDevice=[en-US, en-GB]
installed=[en-US, en-GB]
pending=[]
```

**⏳ Some downloading:**
```
onDevice=[en-US, en-GB, es-ES]
installed=[en-US, en-GB]
pending=[es-ES]
```

**❌ Device not supported:**
```
Debug: On-device recognition not available
```

---

## 🔍 Viewing Logs

### Using Flutter
```bash
flutter logs --tag SpeechDebug
```

### Using adb (Recommended)
```bash
# Show only SpeechDebug logs
adb logcat SpeechDebug:* *:S

# Or grep from full output
adb logcat | grep -E "(onDevice|installed|pending|===)"
```

### Log Format
```
D/SpeechDebug: ===== RECOGNITION SUPPORT DEBUG =====
D/SpeechDebug: onDevice=[en-US, en-GB, ...]
D/SpeechDebug: onDevice count=2
D/SpeechDebug:   - OnDevice: en-US
D/SpeechDebug:   - OnDevice: en-GB
D/SpeechDebug: installed=[en-US, en-GB]
D/SpeechDebug: installed count=2
D/SpeechDebug:   - Installed: en-US
D/SpeechDebug:   - Installed: en-GB
D/SpeechDebug: pending=[]
D/SpeechDebug: pending count=0
D/SpeechDebug: ===== END DEBUG =====
```

---

## ✅ Requirements

| Requirement | Details |
|-------------|---------|
| **Android API** | 33+ (Android 13+) |
| **Device Feature** | On-device speech recognition available |
| **Permissions** | `RECORD_AUDIO` (already required) |
| **Platform** | Android only (iOS returns message) |

---

## 🛠️ Technical Architecture

```
Flutter UI
    ↓ (invoke method channel)
MethodChannel ("speech_debug")
    ↓ (native call)
MainActivity.debugRecognitionSupport()
    ↓ (create recognizer)
SpeechRecognizer.createOnDeviceSpeechRecognizer()
    ↓ (check support)
checkRecognitionSupport() → RecognitionSupportCallback
    ↓ (override)
onSupportResult(RecognitionSupport)
    ↓ (log 3 lists)
Log.d(logTag, ...) × 3
    ↓ (view in)
adb logcat
```

---

## 📝 Integration Checklist

- [ ] Review `QUICK_START_DEBUG.md`
- [ ] Choose integration method
- [ ] Add `SpeechDebugButton` OR call method directly
- [ ] Test on Android 13+ device
- [ ] Verify logs appear in logcat
- [ ] Integrate into your settings/debug UI

---

## 🎯 Use Cases

### 1. **Debug User Language Issues**
```
User: "Spanish isn't working"
You: Run debug → See Spanish is pending/not installed
```

### 2. **Verify Device Capabilities**
```
Device check: Which languages are actually available?
Answer: Check logcat debug output
```

### 3. **Monitor Language Pack Status**
```
Track: Is a language being downloaded?
Answer: Check 'pending' list in debug output
```

### 4. **Optimize Language Selection UI**
```
Show installed languages first (no wait time)
Show pending languages as "coming soon"
Show unsupported as unavailable
```

---

## 🚨 Troubleshooting

### No logs appearing?

**Check 1:** Verify API level
```dart
if (Build.VERSION.SDK_INT < 33) {
  print("API too old - need Android 13+");
}
```

**Check 2:** Restart adb
```bash
adb kill-server
adb start-server
```

**Check 3:** Verify logcat filter
```bash
# Wrong: adb logcat SpeechDebug
# Right: adb logcat SpeechDebug:* *:S
```

### App crashes on debug call?

- Ensure `RECORD_AUDIO` permission is granted
- Verify device supports on-device speech (check "On-device recognition not available" message)
- Check that method channel name matches: `"voice_to_text_conversion/speech_debug"`

### Button doesn't appear?

- Verify import: `import 'package:voice_to_text_conversion/services/speech_debug_helper.dart';`
- Check you're on Android (iOS returns message "only available on Android")
- Verify API 33+ device

---

## 🔗 Related Files

- **Native implementation:** `android/app/src/main/kotlin/com/example/voice_to_text_conversion/MainActivity.kt`
- **Service wrapper:** `lib/services/speech_service.dart`
- **UI widget:** `lib/services/speech_debug_helper.dart`
- **Original plugin:** https://github.com/csdcorp/speech_to_text

---

## 📚 References

- [Android RecognitionSupport](https://developer.android.com/reference/android/speech/RecognitionSupport)
- [SpeechRecognizer.checkRecognitionSupport()](https://developer.android.com/reference/android/speech/SpeechRecognizer#checkRecognitionSupport)
- [Flutter Method Channels](https://flutter.dev/docs/development/platform-integration/platform-channels)
- [speech_to_text plugin](https://pub.dev/packages/speech_to_text)

---

## 💡 Tips & Tricks

### Automate Debug Logging
```dart
// On app startup, log speech support
void initState() {
  super.initState();
  if (kDebugMode) {
    debugRecognitionSupport().then((result) => print('Speech: $result'));
  }
}
```

### Add to Your Settings Page
```dart
class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // ... existing settings ...
        const Divider(),
        const ListTile(
          title: Text('Debug Information'),
          subtitle: SpeechDebugButton(),
        ),
      ],
    );
  }
}
```

### Parse the Results
```dart
final result = await speechService.debugRecognitionSupport();
if (result.contains('Check logcat')) {
  print('✅ Debug call succeeded');
} else if (result.contains('API level')) {
  print('❌ Device API too old');
} else if (result.contains('not available')) {
  print('⚠️ On-device speech not available');
}
```

---

## 🤝 Contributing

This is a self-contained debug system. To extend:

1. Add new methods to `MainActivity.kt` for other native queries
2. Add corresponding Dart wrappers in `speech_service.dart`
3. Create UI widgets as needed

---

## 📄 License

Same as your main Flutter app project.

---

## ✨ Summary

You now have a complete debugging system that:

✅ Logs detailed speech recognition language support directly from Android  
✅ Shows which languages are supported, installed, and pending  
✅ Provides both Flutter widget and direct API access  
✅ Includes comprehensive documentation and examples  
✅ Works on Android 13+ devices  
✅ Helps diagnose user language issues  

**Start with `QUICK_START_DEBUG.md` for immediate usage!**
