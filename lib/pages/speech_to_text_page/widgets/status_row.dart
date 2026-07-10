import 'package:flutter/material.dart';

/// Single line showing the current recognizer status. The full error is
/// surfaced as a tappable warning banner (see [ErrorBanner]) so the message
/// is never truncated.
class StatusRow extends StatelessWidget {
  const StatusRow({
    super.key,
    required this.isListening,
    required this.status,
  });

  final bool isListening;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display =
        isListening ? 'Listening' : (status.isEmpty ? 'Idle' : status);
    final color = isListening
        ? Colors.redAccent
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(
          isListening ? Icons.mic : Icons.mic_none,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text('Status: $display', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Tappable banner that shows a short error summary and reveals the full
/// message in a dialog when tapped. The recognizer error text is long, so we
/// keep the UI compact and let the user open the full details on demand.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.error, required this.onDismiss});

  final String error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 16, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recognition error'),
        content: SingleChildScrollView(
          child: SelectableText(error),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
