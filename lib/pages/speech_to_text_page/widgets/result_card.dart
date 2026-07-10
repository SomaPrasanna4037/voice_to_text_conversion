import 'package:flutter/material.dart';

/// Card that displays the currently recognized text, with a clear button.
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.text,
    required this.isListening,
    required this.onClear,
  });

  final String text;
  final bool isListening;
  final VoidCallback? onClear;

  String get _displayText {
    if (isListening) {
      return text.isEmpty ? 'Listening...' : text;
    }
    if (text.isEmpty) {
      return 'Tap the microphone to start listening.';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    onPressed: isListening ? null : onClear,
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            SelectableText(_displayText, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
