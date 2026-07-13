import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/flutter_speech_service.dart';

class FlutterSpeechToTextPage extends StatelessWidget {
  const FlutterSpeechToTextPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FlutterSpeechService()..initialize(),
      child: const _FlutterSpeechToTextPageContent(),
    );
  }
}

class _FlutterSpeechToTextPageContent extends StatefulWidget {
  const _FlutterSpeechToTextPageContent();

  @override
  State<_FlutterSpeechToTextPageContent> createState() =>
      _FlutterSpeechToTextPageContentState();
}

class _FlutterSpeechToTextPageContentState
    extends State<_FlutterSpeechToTextPageContent> {
  final List<String> _languages = [
    'en-US',
    'en-GB',
    'es-ES',
    'fr-FR',
    'de-DE',
    'it-IT',
    'pt-BR',
    'ja-JP',
    'zh-CN',
    'ko-KR',
    'ar-SA',
  ];

  @override
  void dispose() {
    context.read<FlutterSpeechService>().dispose();
    super.dispose();
  }

  void _toggleListening(FlutterSpeechService speechService) async {
    if (speechService.isListening) {
      await speechService.stopListening();
    } else {
      await speechService.startListening();
    }
  }

  void _handleLanguageChange(String? language, FlutterSpeechService speechService) {
    if (language != null) {
      speechService.setLanguage(language);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FlutterSpeechService>(
      builder: (context, speechService, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Flutter Speech To Text'),
            elevation: 0,
            centerTitle: true,
          ),
          body: speechService.isAvailable
              ? _buildMainContent(speechService)
              : _buildNotAvailableWidget(),
        );
      },
    );
  }

  Widget _buildMainContent(FlutterSpeechService speechService) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language Selection Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Language',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: speechService.language,
                      onChanged: (language) => _handleLanguageChange(language, speechService),
                      items: _languages
                          .map(
                            (lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(lang),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Transcription Display Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transcription',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        speechService.transcript.isEmpty
                            ? 'Tap the microphone to start speaking...'
                            : speechService.transcript,
                        style: TextStyle(
                          fontSize: 16,
                          color: speechService.transcript.isEmpty
                              ? Colors.grey[500]
                              : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Confidence Score
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Confidence:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '${(speechService.confidence * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Listening Status
            if (speechService.isListening)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue[300]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue[700]!,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Listening...',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Error Display
            if (speechService.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red[300]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red[700],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Error',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            speechService.error ?? '',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),

            // Main Action Buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _toggleListening(speechService),
                  icon: Icon(
                    speechService.isListening ? Icons.mic_off : Icons.mic,
                  ),
                  label: Text(
                    speechService.isListening ? 'Stop Listening' : 'Start Listening',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: speechService.isListening
                        ? Colors.red
                        : Colors.indigo,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => speechService.clearTranscript(),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Transcript'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Info Card
            Card(
              color: Colors.blue[50],
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ℹ️ Tips',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Ensure your device has microphone access\n'
                      '• Speak clearly for better recognition\n'
                      '• Check your internet connection for cloud recognition\n'
                      '• Select your preferred language before speaking\n'
                      '• The confidence score indicates recognition accuracy',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotAvailableWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Speech Recognition Not Available',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'This device does not support speech recognition or the required permissions are not granted.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final speechService = context.read<FlutterSpeechService>();
              await speechService.requestPermissions();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }
}
