import 'dart:async';

import 'package:azure_stt_flutter/azure_stt_flutter.dart';
import 'package:flutter/foundation.dart';

/// Azure Speech service wrapper for testing the azure_stt_flutter package.
/// Uses the more reliable azure_stt_flutter package with stream-based API.
/// Exposes state via [ChangeNotifier] for easy integration with the UI.
class AzureSpeechService extends ChangeNotifier {
  late AzureSpeechToText _azureSpeech;
  StreamSubscription<TranscriptionState>? _transcriptionSubscription;

  bool _isAvailable = false;
  bool _isListening = false;
  String _lastWords = '';
  String _finalizedText = '';
  String _intermediateText = '';
  String _status = '';
  String? _error;
  String _currentLocale = 'en-US';
  String? _detectedLanguage;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  String get finalizedText => _finalizedText;
  String get intermediateText => _intermediateText;
  String get status => _status;
  String? get error => _error;
  String get currentLocale => _currentLocale;
  String? get detectedLanguage => _detectedLanguage;

  /// Initializes the Azure Speech service with the provided credentials.
  /// Uses azure_stt_flutter which has better maintenance and stability.
  Future<void> initialize({
    required String subscriptionKey,
    required String region,
    String endpoint = '',
    List<String>? languages,
  }) async {
    try {
      final langs = languages ?? ['en-US'];
      
      // Initialize azure_stt_flutter with subscription key and region
      _azureSpeech = AzureSpeechToText(
        subscriptionKey: subscriptionKey.trim(),
        region: region.trim(),
        languages: langs,
        textClearTimeout: const Duration(seconds: 2),
      );

      // Set up the transcription state stream listener
      _subscribeToTranscriptions();

      _isAvailable = true;
      _status = 'Azure Speech service initialized successfully';
      _error = null;
      _currentLocale = langs.first;
      notifyListeners();

      // ignore: avoid_print
      print('AzureSpeechService: Initialized successfully');
      print('  - Region: $region');
      print('  - Languages: $langs');
    } catch (e, stackTrace) {
      _isAvailable = false;
      _error = 'Failed to initialize Azure Speech: ${e.toString()}';
      // ignore: avoid_print
      print('AzureSpeechService initialization error: $e');
      print('StackTrace: $stackTrace');
      notifyListeners();
    }
  }

  /// Subscribe to transcription state changes from the Azure Speech service
  void _subscribeToTranscriptions() {
    _transcriptionSubscription?.cancel();
    _transcriptionSubscription = _azureSpeech.transcriptionStateStream.listen(
      (TranscriptionState state) {
        _intermediateText = state.intermediateText;
        _finalizedText = state.finalizedText.join(' ');
        _lastWords = state.text;
        _detectedLanguage = state.detectedLanguage;
        
        // Update status
        if (state.isListening) {
          _status = _intermediateText.isNotEmpty ? 'Recognizing...' : 'Listening...';
        } else {
          _status = 'Ready';
        }
        
        notifyListeners();
      },
      onError: (Object error) {
        _error = 'Transcription error: $error';
        _status = 'Error';
        // ignore: avoid_print
        print('Transcription error: $error');
        notifyListeners();
      },
    );
  }

  /// Starts listening for speech input using Azure Speech Recognition.
  /// The azure_stt_flutter package uses streams, so this simply calls startListening()
  /// on the underlying service. Results are streamed via [transcriptionStateStream].
  Future<void> startListening() async {
    if (!_isAvailable) {
      _error = 'Azure Speech service is not initialized.';
      notifyListeners();
      return;
    }

    try {
      _error = null;
      _lastWords = '';
      _intermediateText = '';
      _finalizedText = '';
      _status = 'Listening...';
      _isListening = true;
      notifyListeners();

      await _azureSpeech.startListening();

      // ignore: avoid_print
      print('AzureSpeechService: Started listening');
    } catch (e) {
      _isListening = false;
      _error = 'Failed to start listening: ${e.toString()}';
      _status = 'Error occurred';
      // ignore: avoid_print
      print('AzureSpeechService error: $e');
      notifyListeners();
    }
  }

  /// Stops listening for speech input.
  Future<void> stopListening() async {
    try {
      _azureSpeech.stopListening();
      _isListening = false;
      _status = 'Stopped';
      notifyListeners();
      // ignore: avoid_print
      print('AzureSpeechService: Stopped listening');
    } catch (e) {
      _error = 'Failed to stop listening: ${e.toString()}';
      // ignore: avoid_print
      print('AzureSpeechService error: $e');
      notifyListeners();
    }
  }

  /// Clears the recognized text and any pending error.
  void clearText() {
    if (_lastWords.isEmpty && _error == null) return;
    _lastWords = '';
    _intermediateText = '';
    _finalizedText = '';
    _error = null;
    notifyListeners();
  }

  /// Clears only the error message.
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Dispose resources when the service is no longer needed.
  @override
  void dispose() {
    _transcriptionSubscription?.cancel();
    _azureSpeech.dispose();
    super.dispose();
  }
}
