import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:whisper_kit/whisper_kit.dart';

import 'supported_languages.dart';

/// The Whisper model used for transcription. `base` is a good
/// accuracy/size trade-off (~142 MB) for a POC.
const WhisperModel _kWhisperModel = WhisperModel.base;

/// Filename of the WAV the recorder writes to. We always reuse the
/// same name so we never accumulate stale recordings in temp.
const String _kTempFileName = 'whisper_input.wav';

/// Top-level progress callback handed to `Whisper.onDownloadProgress`.
///
/// **MUST be a top-level function**, not a closure inside an
/// instance method. A closure defined inside an instance method
/// always carries a reference to `this` in its context object;
/// when whisper_kit then tries to invoke that callback from a
/// worker isolate (via `Isolate.run`), Dart refuses with
/// `ArgumentError: object is unsendable` because `this` is a
/// `SpeechService` that transitively owns an `AudioRecorder`,
/// and the recorder's internal `_BroadcastStream` is on the
/// unsendable list.
///
/// A top-level function captures *nothing* — only its arguments —
/// so it can be safely serialized across the isolate boundary.
///
/// Trade-off: we lose the per-byte progress UI on the very first
/// install (the only time the download actually runs). The status
/// line just shows a static "Downloading model…" message in that
/// window. On every subsequent call the model is already cached,
/// so the callback is never invoked anyway.
void _whisperDownloadProgressNoop(int received, int total) {
  // ignore: avoid_print
  print('whisper_kit download progress: $received / $total');
}

/// Wraps the record + whisper_kit flow and exposes its state via
/// [ChangeNotifier]. The page and its widgets only talk to this
/// service.
///
/// Lifecycle:
///
///   1. [initialize] – verifies mic permission (and requests it once
///      on first run). Always succeeds; downstream code treats
///      "permission denied" as a recoverable error and surfaces a
///      friendly message when the user tries to record.
///   2. [startRecording] / [stopRecordingAndTranscribe] – push-to-
///      talk. The mic records to a WAV file (16 kHz, 16-bit, mono)
///      in the app's temp directory; on release the file is handed
///      to whisper_kit.
///   3. [cancelRecording] – discards the in-flight recording without
///      transcribing.
///
/// Modeled on the example app shipped with the package
/// (https://github.com/CodeSagePath/whisper_kit), but with a live
/// mic input instead of bundled WAV assets.
class SpeechService extends ChangeNotifier {
  SpeechService({
    AudioRecorder? recorder,
  }) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// Path of the WAV file the recorder is currently writing to. Set
  /// when [startRecording] succeeds; cleared when the file has been
  /// handed off to whisper_kit (or the recorder is cancelled).
  String? _activeRecordingPath;

  // --- High-level state ----------------------------------------------------

  /// `true` when the user is currently recording from the mic.
  bool _isRecording = false;

  /// `true` while whisper_kit is downloading the model or running
  /// inference. Disables the mic button while true.
  bool _isTranscribing = false;

  /// The transcript of the most recent successful transcription.
  String _text = '';

  /// Plain-text status string shown in the status row.
  String _status = 'Idle';

  /// A user-facing error from the last operation, or `null`.
  String? _error;

  /// Last-known model download progress in the range [0, 1], or
  /// `null` when no download is in flight.
  double? _downloadProgress;

  // --- Selection ------------------------------------------------------------

  /// Selected recognition language. Defaults to `"auto"` (let Whisper
  /// detect the spoken language).
  String _selectedLanguage = 'auto';

  // --- Getters --------------------------------------------------------------

  bool get isRecording => _isRecording;
  bool get isTranscribing => _isTranscribing;
  bool get isBusy => _isRecording || _isTranscribing;
  String get text => _text;
  String get status => _status;
  String? get error => _error;
  double? get downloadProgress => _downloadProgress;
  String get selectedLanguage => _selectedLanguage;
  List<LanguageOption> get languages => supportedLanguages;

  // --- Lifecycle -----------------------------------------------------------

  /// Verifies / requests microphone permission. Always safe to call
  /// from `initState`; the actual gate happens at recording time so
  /// a denial is surfaced as a friendly error, not a startup crash.
  Future<void> initialize() async {
    await Permission.microphone.request();
    notifyListeners();
  }

  /// Resets the last transcript and any pending error.
  void clearText() {
    if (_text.isEmpty && _error == null) return;
    _text = '';
    _error = null;
    notifyListeners();
  }

  /// Releases the recorder and any in-flight recording file. Safe to
  /// call multiple times. The async cleanup is fire-and-forget
  /// because [ChangeNotifier.dispose] is synchronous; the recorder
  /// tears down quickly and we only need to ensure the file is
  /// removed eventually.
  @override
  void dispose() {
    unawaited(_recorder.dispose());
    unawaited(_bestEffortDelete(_activeRecordingPath));
    super.dispose();
  }

  // --- Recording ------------------------------------------------------------

  /// Begins recording from the default microphone. Writes a 16 kHz /
  /// 16-bit / mono WAV file into the app's temp dir — the exact
  /// format whisper_kit's native core expects.
  ///
  /// Returns `true` if recording actually started; `false` if the
  /// user denied mic permission or the platform refused (e.g. a
  /// simulator with no audio input). On `false`, [error] is set.
  Future<bool> startRecording() async {
    if (_isRecording) return true;
    if (_isTranscribing) {
      _error = 'Please wait for the current transcription to finish.';
      notifyListeners();
      return false;
    }

    // Re-check the permission here (rather than trusting
    // `initialize`) because the user may have revoked it from system
    // settings since the last session.
    if (!await _ensureMicPermission()) {
      _error = 'Microphone permission is required to record audio.';
      notifyListeners();
      return false;
    }

    if (!await _recorder.hasPermission()) {
      _error = 'Microphone permission is required to record audio.';
      notifyListeners();
      return false;
    }

    try {
      final path = await _resolveTempPath();
      // ignore: avoid_print
      print('SpeechService: starting recorder, writing to $path');
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      _activeRecordingPath = path;
      _isRecording = true;
      _error = null;
      _status = 'Recording…';
      notifyListeners();
      return true;
    } catch (e, st) {
      // ignore: avoid_print
      print('SpeechService: recorder.start() threw: $e\n$st');
      _isRecording = false;
      _activeRecordingPath = null;
      _error = 'Could not start recording: $e';
      _status = 'Idle';
      notifyListeners();
      return false;
    }
  }

  /// Stops the active recording and hands the resulting WAV file off
  /// to whisper_kit for transcription. Updates [_text] on success.
  ///
  /// The push-to-talk button releases here, so the recorder *must*
  /// be running. We guard with [isRecording] so a stray release
  /// event (e.g. after an error) is a no-op.
  Future<void> stopRecordingAndTranscribe() async {
    if (!_isRecording) return;
    final path = _activeRecordingPath;

    _isRecording = false;
    _status = 'Stopping…';
    notifyListeners();

    String? returnedPath;
    try {
      returnedPath = await _recorder.stop();
      // ignore: avoid_print
      print(
        'SpeechService: recorder.stop() returned: $returnedPath '
        '(asked for: $path)',
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('SpeechService: recorder.stop() threw: $e\n$st');
      _error = 'Could not stop recording: $e';
      _status = 'Idle';
      notifyListeners();
      await _bestEffortDelete(path);
      _activeRecordingPath = null;
      return;
    }

    // The plugin returns the path of the file it actually wrote. If
    // for any reason it returned a different one, prefer that. If it
    // returned `null`, fall back to the path we asked it to write to
    // (the recorder may have written a partial file we can still
    // try to transcribe; whisper_kit will surface a meaningful error
    // if the WAV is unreadable).
    final wavPath = returnedPath ?? path;
    _activeRecordingPath = null;

    if (wavPath == null) {
      _error = 'Recording did not produce a usable audio file.';
      _status = 'Idle';
      notifyListeners();
      return;
    }

    // Log the file's size + existence so we can tell from the log
    // whether whisper_kit got a real WAV or something pathological.
    int wavBytes = 0;
    try {
      final f = File(wavPath);
      wavBytes = await f.length();
    } catch (e) {
      // ignore: avoid_print
      print('SpeechService: could not stat $wavPath: $e');
    }
    // ignore: avoid_print
    print(
      'SpeechService: handing $wavBytes bytes to whisper_kit '
      '(language=$_selectedLanguage)',
    );

    _isTranscribing = true;
    _status = 'Transcribing…';
    _downloadProgress = null;
    notifyListeners();

    // whisper_kit runs `transcribe()` inside `Isolate.run` and
    // invokes `onDownloadProgress` from that worker isolate. If the
    // callback closure captures `this` (the service) — and therefore
    // `_recorder` (an `AudioRecorder` whose `RecordState` stream is
    // a `_BroadcastStream`) — the worker isolate refuses to invoke
    // it with:
    //
    //   ArgumentError: Invalid argument(s): Illegal argument in
    //   isolate message: object is unsendable - Library:'dart:async'
    //   Class: _BroadcastStream
    //
    // The fix is to give whisper_kit a *sendable* handle: a
    // top-level function. The callback running in the worker
    // isolate just logs the progress; we listen on the main
    // isolate and update the service from there.
    //
    // We do *not* try to update the service's UI state from this
    // callback, because:
    //   1. The callback runs in whisper_kit's worker isolate.
    //   2. whisper_kit invokes it from inside `Isolate.run`, so
    //      the callback object (and everything it captures) is
    //      serialized across the isolate boundary.
    //   3. A closure defined inside this instance method always
    //      carries `this` in its context, and `this` transitively
    //      owns an `AudioRecorder` whose internal
    //      `_BroadcastStream` is unsendable.
    // The cleanest fix is to use a *top-level* function that
    // captures nothing — see `_whisperDownloadProgressNoop`.
    //
    // We instead update the status string synchronously before
    // the call, so the UI shows "Downloading model…" the whole
    // time the worker isolate is alive (which covers both the
    // download AND the inference pass).
    _status = 'Downloading model (or transcribing)…';
    notifyListeners();

    try {
      // A fresh Whisper instance per transcription. The
      // `onDownloadProgress` callback is a top-level function so
      // it can be safely invoked from whisper_kit's worker
      // isolate.
      final whisper = Whisper(
        model: _kWhisperModel,
        onDownloadProgress: _whisperDownloadProgressNoop,
      );

      // ignore: avoid_print
      print('SpeechService: calling whisper.transcribe()…');
      final response = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: wavPath,
          language: _selectedLanguage,
          // Whisper translates *to English* when isTranslate is true.
          // For a general-purpose voice-to-text UI we keep the source
          // language by default.
          isTranslate: false,
        ),
      );
      // ignore: avoid_print
      print(
        'SpeechService: transcribe() returned '
        '${response.text.length} chars, segments=${response.segments?.length ?? 0}',
      );
      // ignore: avoid_print
      print('SpeechService: text = "${response.text}"');

      // Always update _text (even if empty) so the UI shows the
      // transcription finished. An empty result usually means
      // whisper's VAD rejected the audio (silence or non-speech).
      _text = response.text.trim();
      _status = 'Idle';
      if (_text.isEmpty) {
        _error =
            'Transcription returned no text. The recording may have '
            'been too quiet or contain no speech. Try again, '
            'speaking closer to the microphone.';
      } else {
        _error = null;
      }
    } on WhisperKitException catch (e, st) {
      // ignore: avoid_print
      print('SpeechService: WhisperKitException: $e\n$st');
      _error = _whisperErrorMessage(e);
      _status = 'Idle';
    } catch (e, st) {
      // ignore: avoid_print
      print('SpeechService: transcribe threw ${e.runtimeType}: $e\n$st');
      _error = 'Transcription failed (${e.runtimeType}): $e';
      _status = 'Idle';
    } finally {
      _isTranscribing = false;
      _downloadProgress = null;
      await _bestEffortDelete(wavPath);
      notifyListeners();
    }
  }

  /// Discards the in-progress recording (if any) and resets the
  /// recorder's internal state. Used when the user explicitly wants
  /// to throw the audio away without transcribing.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    _isRecording = false;
    _status = 'Idle';
    final path = _activeRecordingPath;
    _activeRecordingPath = null;
    try {
      await _recorder.cancel();
    } catch (_) {
      // The recorder may already be in a torn-down state; either way
      // we're throwing the audio away.
    }
    await _bestEffortDelete(path);
    notifyListeners();
  }

  // --- Language selection ---------------------------------------------------

  /// Sets the recognition language. Accepts either `"auto"` (let
  /// Whisper detect) or any of the 99 Whisper-supported language
  /// codes. Unknown codes are silently ignored.
  void selectLanguage(String code) {
    if (_selectedLanguage == code) return;
    if (!isWhisperLanguageCode(code)) return;
    _selectedLanguage = code;
    notifyListeners();
  }

  // --- Helpers --------------------------------------------------------------

  /// Requests microphone permission if it has not yet been decided.
  /// Returns `true` when permission is granted afterwards.
  Future<bool> _ensureMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      // ignore: avoid_print
      print('SpeechService: mic permission permanently denied');
      return false;
    }
    status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Resolves the path the recorder should write to. We always reuse
  /// the same filename so we never accumulate stale WAVs in temp.
  Future<String> _resolveTempPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/$_kTempFileName';
  }

  Future<void> _bestEffortDelete(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // best-effort: don't surface cleanup failures to the UI
    }
  }

  /// Translates a [WhisperKitException] into a user-friendly string.
  /// The package's typed exceptions already produce a useful
  /// `toString()`; we keep this switch so future versions can map
  /// specific sub-types (model, audio, transcription, permission) to
  /// tailored hints.
  String _whisperErrorMessage(WhisperKitException e) {
    // The package's typed exceptions have a `runtimeType` we can
    // branch on without importing every subclass.
    final type = e.runtimeType.toString();
    if (type == 'ModelException') {
      return 'Could not load the Whisper model. Check your network '
          'connection and storage permissions, then try again.';
    }
    if (type == 'AudioException') {
      return 'The recorded audio could not be read. Make sure your '
          'microphone is working and try again.';
    }
    if (type == 'TranscriptionException') {
      return 'Transcription failed. Try recording a longer clip in a '
          'quieter environment.';
    }
    if (type == 'PermissionException') {
      return 'Microphone permission is required to record audio.';
    }
    return 'Whisper error ($type): ${e.toString()}';
  }
}
