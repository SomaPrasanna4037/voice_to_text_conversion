# Quick Start: Speech Debug (30 seconds)

## 1️⃣ Add Widget to Your Page
```dart
import 'package:voice_to_text_conversion/services/speech_debug_helper.dart';

// In your build():
SpeechDebugButton()
```

## 2️⃣ Run the App
```bash
flutter run
```

## 3️⃣ Tap the Debug Button

The button appears in your UI as: **"Debug Speech Recognition"**

## 4️⃣ View the Logs
```bash
adb logcat SpeechDebug:* *:S
```

## 5️⃣ Read the Output

Look for:
```
===== RECOGNITION SUPPORT DEBUG =====
onDevice=[en-US, en-GB, ...]
installed=[en-US, ...]
pending=[]
===== END DEBUG =====
```

---

## What Do I See?

| Output | Meaning |
|--------|---------|
| `onDevice=[...]` | Languages your device CAN support |
| `installed=[...]` | Languages you have DOWNLOADED |
| `pending=[...]` | Languages being DOWNLOADED now |

---

## Example Results

### ✅ All good
```
onDevice=[en-US, en-GB, es-ES]
installed=[en-US, en-GB, es-ES]
pending=[]
```
→ All languages ready to use offline

### ⏳ Downloading
```
onDevice=[en-US, en-GB, es-ES]
installed=[en-US, en-GB]
pending=[es-ES]
```
→ Spanish is downloading, English ready

### ❌ Not available
```
Debug: On-device recognition not available
```
→ Device too old or doesn't support offline speech

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No output in logcat | Restart: `adb kill-server && adb start-server` |
| Button doesn't appear | Check: API level 33+ and on-device speech available |
| App crashes | Verify: RECORD_AUDIO permission is granted |
| See "No result" | Try again — may need a moment to initialize |

---

## Manual Call (No Widget)

```dart
final result = await speechService.debugRecognitionSupport();
print(result); // "Debug: Check logcat..."
```

---

## View Logs Alternative

Without `SpeechDebug` filter:
```bash
adb logcat | grep -E "(onDevice|installed|pending|===)"
```

---

## Files You Modified

| File | Change |
|------|--------|
| `android/app/src/main/.../MainActivity.kt` | Added native debug method |
| `lib/services/speech_service.dart` | Added Dart wrapper |
| `lib/services/speech_debug_helper.dart` | NEW: Debug widget |

---

**Done!** 🎉 You can now inspect which languages your device supports, has installed, and is downloading.

For more details, see:
- `SPEECH_DEBUG_GUIDE.md` — Full technical guide
- `INTEGRATION_EXAMPLE.md` — Integration patterns
- `DEBUG_IMPLEMENTATION_SUMMARY.md` — Architecture overview
