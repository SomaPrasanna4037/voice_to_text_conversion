import 'package:flutter/material.dart';

/// Cluster of FABs: large mic/stop, cancel, and clear.
class ControlButtons extends StatelessWidget {
  const ControlButtons({
    super.key,
    required this.isAvailable,
    required this.isListening,
    required this.hasText,
    required this.onToggleListen,
    required this.onCancel,
    required this.onClear,
  });

  final bool isAvailable;
  final bool isListening;
  final bool hasText;
  final VoidCallback? onToggleListen;
  final VoidCallback? onCancel;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final canToggle = isAvailable;
    final canCancel = isAvailable && isListening;
    final canClear = hasText && !isListening;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FloatingActionButton.large(
          heroTag: 'mic',
          onPressed: canToggle ? onToggleListen : null,
          backgroundColor: isListening
              ? Colors.redAccent
              : Theme.of(context).colorScheme.primary,
          child: Icon(
            isListening ? Icons.stop : Icons.mic,
            size: 32,
            color: Colors.white,
          ),
        ),
        FloatingActionButton(
          heroTag: 'cancel',
          onPressed: canCancel ? onCancel : null,
          tooltip: 'Cancel',
          child: const Icon(Icons.close),
        ),
        FloatingActionButton(
          heroTag: 'clear',
          onPressed: canClear ? onClear : null,
          tooltip: 'Clear text',
          child: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}
