import 'package:flutter/material.dart';

import '../../services/speech_service.dart';
import 'widgets/language_dropdown.dart';
import 'widgets/record_button.dart';
import 'widgets/result_card.dart';
import 'widgets/status_row.dart';

/// Page that hosts the voice-to-text POC.
///
/// Toggle flow:
///   - First tap on the big mic button → service starts recording
///     (a WAV file in the app's temp dir).
///   - Second tap → service stops recording, hands the file to
///     whisper_kit, and updates the result card when the transcript
///     is ready.
class SpeechToTextPage extends StatefulWidget {
  const SpeechToTextPage({super.key});

  @override
  State<SpeechToTextPage> createState() => _SpeechToTextPageState();
}

class _SpeechToTextPageState extends State<SpeechToTextPage> {
  final SpeechService _service = SpeechService();
  String? _lastSurfacedError;

  @override
  void initState() {
    super.initState();
    _service.initialize();
    // Whenever the service changes, surface a SnackBar for any
    // *new* error so the user can't miss it (the inline
    // [ErrorBanner] is easy to overlook, especially on a short
    // push-to-talk flow).
    _service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _service.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    final err = _service.error;
    if (err != null && err != _lastSurfacedError && mounted) {
      _lastSurfacedError = err;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(err),
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } else if (err == null) {
      _lastSurfacedError = null;
    }
  }

  Future<void> _onToggle() async {
    // ignore: avoid_print
    print(
      'SpeechToTextPage._onToggle fired: '
      'isRecording=${_service.isRecording} '
      'isTranscribing=${_service.isTranscribing} '
      'isBusy=${_service.isBusy}',
    );
    if (_service.isRecording) {
      await _service.stopRecordingAndTranscribe();
    } else if (!_service.isTranscribing) {
      // Only start a fresh recording when the service is idle.
      // While transcribing the tap is ignored (the button is
      // disabled in the UI, but we double-check here so a stray
      // tap can never spawn a second recording).
      await _service.startRecording();
    }
  }

  Future<void> _onCancel() async {
    await _service.cancelRecording();
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
              final theme = Theme.of(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LanguageDropdown(
                    languages: _service.languages,
                    selectedCode: _service.selectedLanguage,
                    enabled: !_service.isBusy,
                    onChanged: _service.selectLanguage,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ResultCard(
                        text: _service.text,
                        isBusy: _service.isBusy,
                        onClear: _service.clearText,
                      ),
                    ),
                  ),
                  if (_service.error != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(
                      error: _service.error!,
                      onDismiss: _service.clearText,
                    ),
                  ],
                  const SizedBox(height: 12),
                  StatusRow(
                    status: _service.status,
                    isRecording: _service.isRecording,
                    isTranscribing: _service.isTranscribing,
                    downloadProgress: _service.downloadProgress,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RecordButton(
                          isRecording: _service.isRecording,
                          // The button is interactive whenever the
                          // service is in a state where a tap would
                          // do *something* — i.e. idle (tap to
                          // start) or recording (tap to stop).
                          // The only time we genuinely can't toggle
                          // is mid-transcription, because
                          // `stopRecordingAndTranscribe` and
                          // `startRecording` both call into the
                            // same recorder plugin and would race.
                          isBusy: _service.isTranscribing,
                          onPressed: _onToggle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _service.isTranscribing
                              ? 'Transcribing…'
                              : (_service.isRecording
                                  ? 'Tap to stop and transcribe'
                                  : 'Tap to start recording'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_service.isRecording) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton.icon(
                        onPressed: _onCancel,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancel recording'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
