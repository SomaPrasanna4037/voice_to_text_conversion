import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'speech_service.dart';

/// Helper widget to trigger and display speech recognition debug output.
/// 
/// This widget calls `SpeechService.debugRecognitionSupport()` which logs
/// `RecognitionSupport` details directly from the Android native layer.
/// 
/// Usage:
/// ```dart
/// SpeechDebugButton(
///   speechService: speechService,
///   onDebugResult: (result) {
///     print('Debug result: $result');
///   }
/// )
/// ```
class SpeechDebugButton extends StatefulWidget {
  final SpeechService speechService;
  final void Function(String result)? onDebugResult;

  const SpeechDebugButton({
    Key? key,
    required this.speechService,
    this.onDebugResult,
  }) : super(key: key);

  @override
  State<SpeechDebugButton> createState() => _SpeechDebugButtonState();
}

class _SpeechDebugButtonState extends State<SpeechDebugButton> {
  bool _isDebugging = false;
  String? _debugResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: _isDebugging ? null : _runDebug,
          child: _isDebugging
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Debug Speech Recognition'),
        ),
        if (_debugResult != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _debugResult!,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _runDebug() async {
    setState(() => _isDebugging = true);
    try {
      final result = await widget.speechService.debugRecognitionSupport();
      setState(() => _debugResult = result);
      widget.onDebugResult?.call(result);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debug logged. Check logcat: adb logcat SpeechDebug:* *:S'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() => _debugResult = 'Error: $e');
    } finally {
      setState(() => _isDebugging = false);
    }
  }
}
