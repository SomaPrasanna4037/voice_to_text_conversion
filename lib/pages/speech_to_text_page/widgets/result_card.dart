import 'package:flutter/material.dart';

/// Card that displays the most recent transcript. Renders a hint
/// when no transcript is available.
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.text,
    required this.isBusy,
    this.onClear,
  });

  final String text;

  /// True while the recorder is recording or whisper_kit is
  /// transcribing. Disables the clear button and changes the hint.
  final bool isBusy;

  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String displayText;
    if (isBusy) {
      displayText = text.isEmpty ? 'Working…' : text;
    } else if (text.isEmpty) {
      displayText = 'Hold the microphone and speak, then release to '
          'transcribe.';
    } else {
      displayText = text;
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recognized text', style: theme.textTheme.titleMedium),
                if (text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: isBusy ? null : onClear,
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            SelectableText(displayText, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
