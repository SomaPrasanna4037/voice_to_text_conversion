# voice_to_text_conversion

A Flutter proof-of-concept that demonstrates **voice-to-text** conversion using the
[`speech_to_text`](https://pub.dev/packages/speech_to_text) plugin
([csdcorp/speech_to_text](https://github.com/csdcorp/speech_to_text)).

The app lets the user pick a recognition language from a dropdown (populated with
the locales installed on the device), tap the microphone to start listening, and
see the recognized text in real time.

## Features

- Initializes the `SpeechToText` plugin and surfaces its availability.
- Fetches the list of supported locales from the device and renders them in a
  dropdown so the user can switch recognition language on the fly.
- Live, partial transcription while listening.
- Start, stop, cancel, and clear controls.
- Status and error reporting from the native recognizer.

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Android

Permissions for `RECORD_AUDIO`, `INTERNET`, and the Bluetooth stack are already
declared in `android/app/src/main/AndroidManifest.xml`.

If you target `targetSdkVersion` 30 or later, the manifest already contains the
required `<queries>` block for `android.speech.RecognitionService`.

### 3. iOS

`NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` are
already added to `ios/Runner/Info.plist`.

## Running

```bash
# Start a connected emulator / device first
flutter run
```

> On the iOS simulator you may need to download a voice from
> `Settings → Accessibility → Spoken Content → Voices` before recognition works.
