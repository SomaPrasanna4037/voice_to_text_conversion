import 'package:flutter/material.dart';

/// Compact status line under the result card. Shows the
/// human-readable status (recording, transcribing, downloading
/// model, idle, …) and a colored dot.
class StatusRow extends StatelessWidget {
  const StatusRow({
    super.key,
    required this.status,
    required this.isRecording,
    required this.isTranscribing,
    this.downloadProgress,
  });

  final String status;
  final bool isRecording;
  final bool isTranscribing;
  final double? downloadProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color color;
    final IconData icon;
    if (isRecording) {
      color = Colors.redAccent;
      icon = Icons.fiber_manual_record;
    } else if (isTranscribing) {
      color = theme.colorScheme.primary;
      icon = Icons.hourglass_top;
    } else {
      color = theme.colorScheme.onSurfaceVariant;
      icon = Icons.mic_none;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Status: $status',
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (downloadProgress != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: LinearProgressIndicator(
              value: downloadProgress,
              minHeight: 4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Tappable banner that shows a short error summary and reveals the
/// full message in a dialog when tapped. The error text can be long,
/// so we keep the UI compact and let the user open the full details
/// on demand.
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
        title: const Text('Transcription error'),
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
