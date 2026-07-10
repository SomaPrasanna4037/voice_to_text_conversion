# Integration Example: Using Speech Debug in Your App

## Quick Start: Add Debug Button to Settings Page

Here's a complete example of how to add the debug functionality to your existing speech-to-text page:

### 1. Import the Debug Helper

```dart
import 'package:voice_to_text_conversion/services/speech_debug_helper.dart';
```

### 2. Add the Widget to Your Build

```dart
class SpeechSettingsPage extends StatefulWidget {
  @override
  State<SpeechSettingsPage> createState() => _SpeechSettingsPageState();
}

class _SpeechSettingsPageState extends State<SpeechSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speech Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ... your existing speech settings UI ...
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            
            // Add the debug button
            const Text(
              'Debug Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SpeechDebugButton(
              onDebugResult: (result) {
                print('Debug result: $result');
                // Optionally show a toast or snackbar
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

### 3. View the Output

Run the app and tap the "Debug Speech Recognition" button:

```bash
# In a terminal, run:
adb logcat SpeechDebug:* *:S
```

You'll see output like:
```
D SpeechDebug: ===== RECOGNITION SUPPORT DEBUG =====
D SpeechDebug: onDevice=[en-US, en-GB, es-ES, ...]
D SpeechDebug: onDevice count=4
D SpeechDebug:   - OnDevice: en-US
...
```

---

## Advanced Usage: Custom Integration

If you want to handle the result yourself instead of using the widget:

```dart
class MyCustomPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Debug')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _runDebug(context),
          child: const Text('Run Debug'),
        ),
      ),
    );
  }

  Future<void> _runDebug(BuildContext context) async {
    final speechService = context.read<SpeechService>();
    
    // Show loading dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Debugging...'),
        content: const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final result = await speechService.debugRecognitionSupport();
      
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show result dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Debug Result'),
          content: SingleChildScrollView(
            child: SelectableText(result),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      
      print('Debug output: $result');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
```

---

## Interpreting the Debug Output

### Understanding `supportedOnDeviceLanguages`

These are languages the device's recognizer claims to support on-device (may require downloading).

Example:
```
onDevice=[en-US, en-GB, es-ES, fr-FR, de-DE]
```

### Understanding `installedOnDeviceLanguages`

These are languages that are **already downloaded** and ready to use without network.

Example:
```
installed=[en-US, en-GB]
```

If `en-GB` is supported but not installed, the user can download it from Settings → Languages.

### Understanding `pendingOnDeviceLanguages`

These are languages that are **in the process of being downloaded**.

Example:
```
pending=[es-ES, fr-FR]
```

---

## Common Scenarios

### Scenario 1: Device with offline packs installed
```
onDevice=[en-US, en-GB]        // 2 languages available
installed=[en-US, en-GB]       // Both are installed
pending=[]                      // Nothing pending
```
✅ **Result**: All listed languages can be used offline.

### Scenario 2: New language available but not installed
```
onDevice=[en-US, en-GB, es-ES]  // 3 languages available
installed=[en-US, en-GB]        // Only 2 installed
pending=[]                       // None downloading
```
✅ **Result**: User can download `es-ES` from Settings, or use it via network.

### Scenario 3: Device downloading a language
```
onDevice=[en-US, en-GB, fr-FR]  // 3 available
installed=[en-US, en-GB]        // 2 installed
pending=[fr-FR]                 // 1 downloading
```
⏳ **Result**: `fr-FR` will be available offline once download completes.

### Scenario 4: No on-device models available
```
"Debug: On-device recognition not available"
```
❌ **Result**: Device doesn't support on-device speech (older device or no Google app).

---

## Integration with Your Language Selector

You can use the debug output to improve your language dropdown logic:

```dart
Future<void> _loadLanguages() async {
  final speechService = context.read<SpeechService>();
  
  // Load the standard languages
  await speechService.loadLanguages();
  
  // Optionally, log what's actually on the device
  final debugInfo = await speechService.debugRecognitionSupport();
  debugPrint('Speech support: $debugInfo');
  
  // Your language selector now has accurate info
  // about which languages are installed vs pending
}
```

---

## Notes

- **First time**: The debug output might be empty if this is the first time the device is querying speech support.
- **Network-only mode**: If all languages show as "supported" but not installed, the device likely only uses network speech recognition.
- **Regional variants**: Look for entries like `en-GB`, `pt-BR`, etc. Not all variants are available on all devices.

For more details, see `SPEECH_DEBUG_GUIDE.md`.
