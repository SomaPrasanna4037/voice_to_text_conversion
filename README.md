# voice_to_text_conversion

A Flutter proof-of-concept that demonstrates **voice-to-text** conversion using the
[`stts`](https://pub.dev/packages/stts) plugin
([llfbandit/stts](https://github.com/llfbandit/stts)).

The app lets the user pick a recognition language from a dropdown (populated with
the locales installed on the device), tap the microphone to start listening, and
see the recognized text in real time.

## Features

- Initializes the `Stt` plugin and surfaces its availability.
- Fetches the list of supported locales from the device and renders them in a
  dropdown so the user can switch recognition language on the fly.
- Live, partial transcription while listening (via `Stt.onResultChanged`).
- Start, stop, cancel, and clear controls.
- Status and error reporting from the native recognizer (delivered through
  `Stt.onStateChanged` and the stream's `onError` callback).

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Android

Permissions for `RECORD_AUDIO` and `INTERNET` are already declared in
`android/app/src/main/AndroidManifest.xml`. The Android 11+ `<queries>` block
for `android.speech.RecognitionService` is also present, so speech recognition
services remain visible to the plugin.

### 3. iOS

`NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` are
already added to `ios/Runner/Info.plist`. The plugin also requires iOS 12.0 or
later (matches Flutter's current minimum).

## Running

```bash
# Start a connected emulator / device first
flutter run
```

> On the iOS simulator you may need to download a voice from
> `Settings → Accessibility → Spoken Content → Voices` before recognition works.
