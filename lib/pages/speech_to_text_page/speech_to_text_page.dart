import 'package:flutter/material.dart';

import '../../services/speech_debug_helper.dart';
import '../../services/speech_service.dart';
import 'widgets/availability_card.dart';
import 'widgets/control_buttons.dart';
import 'widgets/locale_dropdown.dart';
import 'widgets/result_card.dart';
import 'widgets/status_row.dart';

/// Page that hosts the voice-to-text POC.
///
/// Owns a [SpeechService] instance and rebuilds the small widgets underneath
/// whenever the service reports a change.
class SpeechToTextPage extends StatefulWidget {
  const SpeechToTextPage({super.key});

  @override
  State<SpeechToTextPage> createState() => _SpeechToTextPageState();
}

class _SpeechToTextPageState extends State<SpeechToTextPage> with WidgetsBindingObserver {
  final SpeechService _service = SpeechService();

  @override
  void initState() {
    super.initState();
    _service.initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user comes back from the system speech settings, the list of
    // available locales may have changed (they just installed Tamil, etc.).
    if (state == AppLifecycleState.resumed) {
      _service.refreshLocales();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_service.isListening) {
      await _service.stopListening();
    } else {
      await _service.startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice to Text POC'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  AvailabilityCard(isAvailable: _service.isAvailable),
                  const SizedBox(height: 16),
                  LocaleDropdown(
                    languages: _service.languages,
                    selectedCode: _service.selectedCode,
                    selectedDeviceLocaleId: _service.selectedDeviceLocaleId,
                    enabled: _service.canChangeLocale,
                    onChanged: _service.selectLocale,
                    onDeviceLocaleChanged: _service.selectDeviceLocale,
                    deviceLocales: _service.unmatchedDeviceLocales,
                  ),
                  const SizedBox(height: 16),
                  ResultCard(
                    text: _service.lastWords,
                    isListening: _service.isListening,
                    onClear: _service.clearText,
                  ),
                  if (_service.error != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(
                      error: _service.error!,
                      onDismiss: _service.clearText,
                    ),
                  ],
                  const SizedBox(height: 16),
                  StatusRow(
                    isListening: _service.isListening,
                    status: _service.status,
                  ),
                  const SizedBox(height: 8),
                  ControlButtons(
                    isAvailable: _service.isAvailable,
                    isListening: _service.isListening,
                    hasText: _service.lastWords.isNotEmpty,
                    onToggleListen: _toggleListening,
                    onCancel: _service.cancelListening,
                    onClear: _service.clearText,
                  ),
                  const SizedBox(height: 12),
                  SpeechDebugButton(
                    speechService: _service,
                    onDebugResult: (result) {
                      print('✅ DEBUG RESULT: $result');
                    },
                  ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
