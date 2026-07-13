# voice_to_text_conversion

A Flutter proof-of-concept that records audio from the device microphone and
transcribes it on-device with [whisper_kit](https://pub.dev/packages/whisper_kit)
(OpenAI Whisper via [whisper.cpp](https://github.com/ggerganov/whisper.cpp)).

The mic records to a temporary WAV file (16 kHz, 16-bit PCM, mono) using
[record](https://pub.dev/packages/record), and that file is then handed to
whisper_kit for transcription. The whole pipeline runs on-device; the Whisper
model is downloaded once on first use and then cached.

Modeled on the [example app shipped with whisper_kit](https://github.com/CodeSagePath/whisper_kit/tree/master/example),
but with a live mic input instead of bundled WAV assets.

## Features

- Tap-to-toggle mic control (tap to start, tap again to stop and transcribe).
- Cancel recording without transcribing.
- A flat language dropdown with **Auto-detect** plus the most common
  Whisper-supported languages.
- Live status line showing idle / recording / transcribing / model-download
  progress.
- Friendly error messages for the typed `WhisperKitException` subclasses
  (model, audio, transcription, permission).

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Android

The mic permission and internet permission (for the one-time model download) are
already declared in `android/app/src/main/AndroidManifest.xml`.

### 3. iOS

`NSMicrophoneUsageDescription` is already in `ios/Runner/Info.plist`. The
`NSSpeechRecognitionUsageDescription` key is no longer required because
whisper_kit does not use Apple's on-device speech recognizer.

## Running

```bash
# Start a connected emulator / device first
flutter run
```

> The first time you tap the mic, whisper_kit will download the
> Whisper `base` model (~142 MB). The download progress is shown in the status
> line. After that, transcription runs fully offline.
