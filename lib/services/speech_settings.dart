import 'package:flutter/services.dart';

/// Thin wrapper around the platform channel that opens the system screen
/// where the user can install / download additional speech-recognition
/// languages. The actual native implementation lives in
/// `android/app/src/main/kotlin/.../MainActivity.kt`.
class SpeechSettings {
  SpeechSettings._();

  static const MethodChannel _channel = MethodChannel(
    'voice_to_text_conversion/speech_settings',
  );

  /// Opens the speech settings on the device.
  ///
  /// Returns the destination that was reached:
  ///  - `google` – the Google app's voice/language screen
  ///  - `offline_speech` – Android 12+ offline speech settings
  ///  - `app_details` – this app's details page (last-resort fallback)
  ///  - `unavailable` – nothing could be opened
  ///  - `unsupported` – not running on Android
  static Future<String> openSpeechSettings() async {
    try {
      final result = await _channel.invokeMethod<String>('openSpeechSettings');
      return result ?? 'unavailable';
    } on MissingPluginException {
      return 'unsupported';
    } on PlatformException {
      return 'unavailable';
    }
  }
}
