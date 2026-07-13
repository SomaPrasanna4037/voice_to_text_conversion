import 'package:flutter/material.dart';

/// Big round start/stop recording button.
///
/// Renders a mic icon when idle and a stop icon while recording.
/// A single tap toggles the state — first tap starts recording,
/// second tap stops and triggers transcription. The widget is
/// disabled while [isBusy] is true.
class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.isBusy,
    required this.onPressed,
  });

  final bool isRecording;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = !isBusy && onPressed != null;
    final color = isRecording
        ? Colors.redAccent
        : (enabled ? scheme.primary : scheme.surfaceContainerHighest);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 96,
          width: 96,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: isRecording ? 18 : 8,
                spreadRadius: isRecording ? 2 : 0,
              ),
            ],
          ),
          child: Icon(
            isRecording ? Icons.stop : Icons.mic,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }
}
