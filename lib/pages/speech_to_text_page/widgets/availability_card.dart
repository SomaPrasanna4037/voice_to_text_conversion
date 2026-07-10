import 'package:flutter/material.dart';

/// Small banner that tells the user whether speech recognition is available.
class AvailabilityCard extends StatelessWidget {
  const AvailabilityCard({super.key, required this.isAvailable});

  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              isAvailable ? Icons.check_circle : Icons.error_outline,
              color: isAvailable ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isAvailable
                    ? 'Speech recognition is available on this device.'
                    : 'Speech recognition is not available. Check permissions and that the recognizer is enabled.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
