import 'package:flutter/foundation.dart';
import 'package:flutter_speech_to_text/flutter_speech_to_text.dart';

/// Service wrapper for [flutter_speech_to_text] package.
/// Provides stream-based access to speech recognition with real-time updates.
class FlutterSpeechService extends ChangeNotifier {
  FlutterSpeechService({SpeechToText? speechToText})
    : _speechToText = speechToText ?? SpeechToText();

  final SpeechToText _speechToText;

  String _transcript = '';
  double _confidence = 0.0;
  bool _isListening = false;
  bool _isAvailable = false;
  String? _error;
  String _language = 'en-US';
  final List<String> _supportedLanguages = [];

  String get transcript => _transcript;
  double get confidence => _confidence;
  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String? get error => _error;
  String get language => _language;
  List<String> get supportedLanguages => _supportedLanguages;

  /// Initializes the speech recognition service
  Future<void> initialize() async {
    try {
      _isAvailable = await _speechToText.isAvailable();
      _setupStreamListeners();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize: $e';
      _isAvailable = false;
      notifyListeners();
    }
  }

  /// Sets up listeners for speech recognition streams
  void _setupStreamListeners() {
    // Listen for results
    _speechToText.onResult.listen((result) {
      _transcript = result.transcript;
      _confidence = result.confidence;
      notifyListeners();
    });

    // Listen for errors
    _speechToText.onError.listen((error) {
      _error = error.message;
      _isListening = false;
      notifyListeners();
    });

    // Listen for end of speech
    _speechToText.onEnd.listen((_) {
      _isListening = false;
      notifyListeners();
    });
  }

  /// Requests microphone permissions and starts listening
  Future<void> startListening({String? language}) async {
    try {
      _error = null;

      if (!_isAvailable) {
        _error = 'Speech recognition not available on this device';
        notifyListeners();
        return;
      }

      // Request permissions
      final hasPermission = await _speechToText.requestPermissions();
      if (!hasPermission) {
        _error = 'Microphone permission denied';
        notifyListeners();
        return;
      }

      // Clear previous transcript
      _transcript = '';
      _confidence = 0.0;

      // Start listening
      final lang = language ?? _language;
      await _speechToText.start();
      _isListening = true;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to start listening: $e';
      _isListening = false;
      notifyListeners();
    }
  }

  /// Stops listening and returns the final transcript
  Future<void> stopListening() async {
    try {
      await _speechToText.stop();
      _isListening = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to stop listening: $e';
      notifyListeners();
    }
  }

  /// Requests microphone permissions
  Future<bool> requestPermissions() async {
    try {
      return await _speechToText.requestPermissions();
    } catch (e) {
      _error = 'Permission request failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Opens system settings for speech recognition permissions
  Future<bool> openSettings() async {
    try {
      return await _speechToText.openSettings();
    } catch (e) {
      _error = 'Failed to open settings: $e';
      notifyListeners();
      return false;
    }
  }

  /// Sets the language for speech recognition
  void setLanguage(String language) {
    _language = language;
    notifyListeners();
  }

  /// Clears the current transcript
  void clearTranscript() {
    _transcript = '';
    _confidence = 0.0;
    _error = null;
    notifyListeners();
  }

  /// Clears the error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _speechToText.dispose();
    super.dispose();
  }
}
