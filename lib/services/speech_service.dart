import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:stts/stts.dart';

import 'supported_languages.dart';

/// After `stop()` we wait this long for the platform audio session to
/// release before calling `start()` again. `stts` does not surface a
/// `cancelOnError` / `busy` error, but the underlying recognizer can
/// still throw if the next session is created while the previous task
/// is tearing down (especially on iOS).
const Duration _kPostStopDelay = Duration(milliseconds: 400);
const Duration _kPostStopDelayIOS = Duration(milliseconds: 1500);

/// True when the current platform benefits from enabling
/// `SttRecognitionOptions.punctuation`. Apple's `addsPunctuation` path
/// requires the server-side recognizer — on iOS this can cause
/// recognizer-init failures when offline-only. The Android recognizer
/// uses punctuation locally and is safe to enable.
bool get _kPunctuationEnabled => !Platform.isIOS;

/// Returns true if the error message looks like a recoverable hiccup
/// the recognizer can ride through without user intervention. These
/// are quietly ignored at the UI level; the recognizer has already
/// stopped and the user can tap the mic to retry.
bool _isRecoverableError(String msg) {
  final lower = msg.toLowerCase();
  return lower.contains('error_no_match') ||
      lower.contains('error_speech_timeout') ||
      lower.contains('error_busy') ||
      lower.contains('error_network') ||
      lower.contains('error_server') ||
      lower.contains('error_too_many_requests');
}

/// Wraps the [Stt] plugin and exposes its state via [ChangeNotifier].
///
/// The page and its widgets only talk to this service, so they stay
/// stateless and easy to read.
class SpeechService extends ChangeNotifier {
  SpeechService({Stt? stt}) : _stt = stt ?? Stt();

  final Stt _stt;
  StreamSubscription<SttState>? _stateSub;
  StreamSubscription<SttRecognition>? _resultSub;

  bool _isAvailable = false;
  bool _isListening = false;
  String _lastWords = '';
  String _status = '';
  String? _error;

  /// The curated, user-facing list of languages this app supports,
  /// annotated with whether each one is actually installed on the device.
  List<LanguageEntry> _languages = const [];

  /// Locales the device's recognizer reports in `getLanguages()` that
  /// do NOT match any curated [LanguageConfig.bcp47]. These are shown
  /// at the bottom of the dropdown as a "Default locales" section so
  /// the user can see what's installed but not curated.
  List<String> _unmatchedDeviceLocales = const [];

  /// The currently selected language's stable [LanguageConfig.code].
  String? _selectedCode;

  /// The raw device locale id (e.g. `"zh-HK"`) of a "Default locales"
  /// entry the user picked from the dropdown. This is non-null only
  /// when the user explicitly chose a device-only locale that isn't in
  /// the curated [supportedLanguages] list. Mutually exclusive with
  /// [_selectedCode] in practice (picking one clears the other).
  String? _selectedDeviceLocaleId;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  String get status => _status;
  String? get error => _error;

  /// The curated list of recognition languages the user can pick from.
  /// Order matches [supportedLanguages]; each entry knows whether the
  /// underlying recognizer on this device actually supports it.
  List<LanguageEntry> get languages => _languages;

  /// The stable id of the currently selected recognition language
  /// (matches [LanguageConfig.code], e.g. `"en-GB"`, `"ta"`), or `null`
  /// if nothing usable is available.
  String? get selectedCode => _selectedCode;

  /// Locales the device's recognizer reports in `getLanguages()` that
  /// do NOT match any curated [LanguageConfig.bcp47]. Shown at the
  /// bottom of the dropdown as a selectable "Default locales" section.
  List<String> get unmatchedDeviceLocales => _unmatchedDeviceLocales;

  /// The BCP-47 tag of the currently selected language (the value we
  /// actually hand to `Stt.setLanguage(...)`). `null` if nothing is
  /// selected. Falls back to the user-picked device-only locale id
  /// when no curated entry is selected.
  String? get selectedBcp47 {
    if (_selectedCode != null) {
      final entry = _findByCode(_selectedCode!);
      if (entry != null) return entry.config.bcp47;
    }
    return _selectedDeviceLocaleId;
  }

  /// The raw device locale id of a "Default locales" entry the user
  /// picked, or `null` if no such entry is currently selected.
  String? get selectedDeviceLocaleId => _selectedDeviceLocaleId;

  /// True when the user can change the recognition language.
  bool get canChangeLocale => _isAvailable && !_isListening;

  /// Initializes the underlying recognizer and loads available locales.
  Future<void> initialize() async {
    // Check whether the platform offers a recognizer at all.
    _isAvailable = await _stt.isSupported();

    if (_isAvailable) {
      // Request microphone / speech recognition permission up front.
      // The plugin returns `false` if the user denies; we surface that
      // as the page's "not available" state.
      final granted = await _stt.hasPermission();
      if (!granted) {
        _isAvailable = false;
      }
    }

    // Subscribe to state and result streams regardless of availability
    // so the UI can react to lifecycle changes immediately.
    _stateSub = _stt.onStateChanged.listen(
      _handleState,
      onError: _handleStreamError,
    );
    _resultSub = _stt.onResultChanged.listen(_handleResult);

    await _loadLocales();
    notifyListeners();
  }

  /// Re-fetches the list of supported locales from the plugin. Call this
  /// after the user comes back from the system speech-settings screen so
  /// newly-installed languages show up in the dropdown.
  Future<void> refreshLocales() async {
    await _loadLocales();
    notifyListeners();
  }

  Future<void> _loadLocales() async {
    final deviceLocales = await _safeGetLanguages();
    final currentLanguage = await _safeGetLanguage();

    _languages = _buildEntries(deviceLocales);
    _unmatchedDeviceLocales = _computeUnmatchedDeviceLocales(deviceLocales);

    // If the user previously picked a device-only locale but the device
    // no longer reports it, drop the selection so the dropdown doesn't
    // hold onto a stale value.
    if (_selectedDeviceLocaleId != null &&
        !_unmatchedDeviceLocales.contains(_selectedDeviceLocaleId)) {
      // Also check the curated list — the device may have re-installed
      // the language and it might now match a curated entry, in which
      // case the dropdown will show it via `_selectedCode` instead.
      final stillInCurated = _languages.any(
        (e) =>
            _selectedDeviceLocaleId == e.config.code ||
            _selectedDeviceLocaleId == e.config.bcp47 ||
            _selectedDeviceLocaleId == e.config.sttLocale,
      );
      if (!stillInCurated) {
        _selectedDeviceLocaleId = null;
      }
    }

    _selectedCode = _resolveDefaultCode(
      _languages,
      _selectedCode,
      currentLanguage,
    );
  }

  /// `getLanguages()` can throw on platforms that don't support it
  /// (e.g. before permission is granted). Returns an empty list in
  /// that case so the dropdown can show its "nothing available" hint
  /// instead of crashing the load path.
  Future<List<String>> _safeGetLanguages() async {
    if (!_isAvailable) return const [];
    try {
      return await _stt.getLanguages();
    } catch (e) {
      // ignore: avoid_print
      print('SpeechService: getLanguages() failed: $e');
      return const [];
    }
  }

  /// `getLanguage()` returns the recognizer's *current* setting (the
  /// id most recently passed to `setLanguage(...)`). It is `null`-able
  /// in spirit — when nothing has been set yet, the plugin may return
  /// the system default or an empty string. We treat the result
  /// defensively here.
  Future<String?> _safeGetLanguage() async {
    if (!_isAvailable) return null;
    try {
      final value = await _stt.getLanguage();
      return value.isEmpty ? null : value;
    } catch (e) {
      // ignore: avoid_print
      print('SpeechService: getLanguage() failed: $e');
      return null;
    }
  }

  /// Returns the subset of [deviceLocales] whose id doesn't match any
  /// curated [LanguageConfig.bcp47]. `stts` always emits BCP-47 in
  /// hyphen form, so the match is straightforward — no underscore
  /// normalization needed.
  List<String> _computeUnmatchedDeviceLocales(List<String> deviceLocales) {
    final curatedIds = <String>{
      for (final cfg in supportedLanguages)
        if (cfg.bcp47.isNotEmpty) cfg.bcp47,
    };
    return [
      for (final id in deviceLocales)
        if (!curatedIds.contains(id)) id,
    ];
  }

  /// Cross-references [supportedLanguages] with the locales the device's
  /// recognizer actually has. `stts` always reports ids in BCP-47 hyphen
  /// form, and our curated `bcp47` is also hyphen form, so matching is
  /// direct. The `sttLocale` field on each entry is kept for backwards
  /// compatibility (it now mirrors `bcp47`) and to flag curated entries
  /// that aren't actually present on the device as cloud-only.
  List<LanguageEntry> _buildEntries(List<String> deviceLocales) {
    final deviceIds = deviceLocales.toSet();
    return [
      for (final cfg in supportedLanguages)
        LanguageEntry(
          config: cfg,
          isAvailable: deviceIds.contains(cfg.bcp47),
          isCloudOnly: cfg.sttLocale == null,
        ),
    ];
  }

  LanguageEntry? _findByCode(String code) {
    for (final entry in _languages) {
      if (entry.config.code == code) return entry;
    }
    return null;
  }

  /// Picks the best default selection from the curated list. Prefers the
  /// user's current choice, then the current recognizer language (if
  /// any curated entry matches it), then the first available curated
  /// language.
  String? _resolveDefaultCode(
    List<LanguageEntry> entries,
    String? currentCode,
    String? systemLocaleId,
  ) {
    if (currentCode != null) {
      final current = _findByCode(currentCode);
      if (current != null && current.isAvailable) return current.config.code;
    }

    if (systemLocaleId != null) {
      // The plugin reports ids in BCP-47 hyphen form, the curated list
      // uses the same form. Find a curated entry whose `bcp47` matches
      // the system's id, preferring an exact match and falling back to
      // a base-language match.
      final code = _matchCuratedByBcp47(systemLocaleId, entries);
      if (code != null) return code;
    }

    for (final entry in entries) {
      if (entry.isAvailable) return entry.config.code;
    }

    // Last resort: nothing is available on the device. Return `null` so
    // the dropdown can show its "No languages available" hint.
    return null;
  }

  /// Returns the [LanguageConfig.code] of the curated entry whose
  /// [LanguageConfig.bcp47] matches [systemLocaleId] AND whose
  /// [LanguageEntry.isAvailable] is `true` in the supplied [entries].
  /// Returns `null` if nothing matches.
  String? _matchCuratedByBcp47(
    String systemLocaleId,
    List<LanguageEntry> entries,
  ) {
    bool? isAvailableFor(LanguageConfig cfg) {
      for (final e in entries) {
        if (e.config.code == cfg.code) return e.isAvailable;
      }
      return null;
    }

    // Exact match.
    for (final cfg in supportedLanguages) {
      if (cfg.bcp47 == systemLocaleId) {
        if (isAvailableFor(cfg) == true) return cfg.code;
      }
    }
    // Base-language fallback (e.g. system `en-US` -> curated `en-GB`).
    final base = systemLocaleId.split('-').first;
    for (final cfg in supportedLanguages) {
      final cfgBase = cfg.bcp47.split('-').first;
      if (cfgBase == base && isAvailableFor(cfg) == true) return cfg.code;
    }
    return null;
  }

  void _handleState(SttState sttState) {
    _isListening = sttState == SttState.start;
    _status = sttState == SttState.start ? 'listening' : 'idle';
    notifyListeners();
  }

  /// Called when the [onStateChanged] stream emits an error. The
  /// plugin surfaces native errors as `Object` (typically a string
  /// message from the platform side). We classify them by message
  /// content and either swallow the recoverable ones or surface a
  /// user-friendly error.
  void _handleStreamError(Object error) {
    // Also log to the console so it's easy to find in `flutter logs`.
    // ignore: avoid_print
    print('SpeechService error: $error');
    _isListening = false;
    _status = 'idle';
    notifyListeners();

    if (_isRecoverableError(error.toString())) {
      // Don't show these in the UI — they happen on every short
      // silence and would just flash an error banner constantly.
      // The recognizer has already stopped; the user can tap the
      // mic to retry.
      _error = null;
      notifyListeners();
      return;
    }

    // Anything else: stop the session, surface the error, and let the
    // user retry. `stts` does not have an explicit fatal/permanent
    // distinction on errors, so we treat every non-recoverable
    // message as a soft error the user can resolve by tapping the
    // mic again.
    _error = _formatError(error);
    notifyListeners();
  }

  /// Builds a readable error message. The raw string is often a
  /// terse code (e.g. `error_no_match`) or a platform-internal
  /// message (e.g. `kLSRErrorDomain Code=300 ...`); we add a hint
  /// for the common cases.
  String _formatError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    String? hint;
    if (lower.contains('permission')) {
      hint = 'Microphone / speech recognition permission is denied. '
          'Enable it in system Settings.';
    } else if (lower.contains('network')) {
      hint = 'Network recognition failed. Check the device\'s internet '
          'connection.';
    } else if (lower.contains('no_match')) {
      hint = 'The recognizer heard audio but could not match it to any '
          'words. This often happens with TTS playback — try speaking '
          'naturally instead, or play the audio louder / closer to the '
          'mic.';
    } else if (lower.contains('speech_timeout')) {
      hint = 'No speech was detected for a while. Check that the device '
          'microphone is unmuted and the audio source is loud enough.';
    } else if (lower.contains('audio')) {
      hint = 'There was a problem with the audio input. Check that no '
          'other app is using the microphone.';
    } else if (lower.contains('language') || lower.contains('locale')) {
      hint = 'The selected recognition language isn\'t available on this '
          'device. Try a different language or install the offline pack.';
    }
    if (hint != null) return 'Recognition error ($raw)\n$hint';
    return 'Recognition error: $raw';
  }

  void _handleResult(SttRecognition result) {
    _lastWords = result.text;
    notifyListeners();
  }

  /// Updates the currently selected recognition language by its stable
  /// [LanguageConfig.code] (e.g. `"en-GB"`, `"ta"`). Accepts any
  /// curated entry — available, not-installed, or cloud-only — so the
  /// user can pick a language the device doesn't have on-device and
  /// let the recognizer fall back to the network. Silently ignores
  /// ids that aren't in [languages]. Clears any pending device-only
  /// selection.
  void selectLocale(String code) {
    if (_selectedCode == code && _selectedDeviceLocaleId == null) return;
    final entry = _findByCode(code);
    if (entry == null) return;
    _selectedCode = entry.config.code;
    _selectedDeviceLocaleId = null;
    notifyListeners();
  }

  /// Selects a "Default locales" entry — a device-only locale that
  /// isn't in the curated [supportedLanguages] list. The id must
  /// currently be reported by `getLanguages()` and not match any
  /// curated entry (i.e. it must be in [unmatchedDeviceLocales]).
  /// Clears any pending curated selection.
  void selectDeviceLocale(String localeId) {
    if (localeId == _selectedDeviceLocaleId && _selectedCode == null) return;
    if (!_unmatchedDeviceLocales.contains(localeId)) return;
    _selectedCode = null;
    _selectedDeviceLocaleId = localeId;
    notifyListeners();
  }

  /// Starts a new recognition session.
  ///
  /// Defensively stops any stale session and waits briefly before
  /// `start()` to let the platform audio session settle. The plugin
  /// docs recommend this when interacting with other audio plugins
  /// and it also helps when the previous session errored out.
  Future<void> startListening() async {
    if (!_isAvailable) {
      _error = 'Speech recognition is not available on this device.';
      notifyListeners();
      return;
    }
    final bcp47 = selectedBcp47;
    if (bcp47 == null) {
      _error = 'No recognition language selected.';
      notifyListeners();
      return;
    }

    _error = null;
    notifyListeners();

    // Clear any stale native state from a previous (possibly failed)
    // session.
    try {
      await _stt.stop();
    } catch (_) {
      // ignore: stop failures — we just want a clean slate
    }
    await Future<void>.delayed(
      Platform.isIOS ? _kPostStopDelayIOS : _kPostStopDelay,
    );

    try {
      await _stt.setLanguage(bcp47);
      await _stt.start(
        SttRecognitionOptions(punctuation: _kPunctuationEnabled),
      );
      // The state stream will flip `_isListening` to true; we keep
      // the local flag in sync optimistically so the UI updates
      // immediately rather than waiting for the next frame.
      _isListening = true;
      _status = 'listening';
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print('SpeechService: start() threw: $e');
      _isListening = false;
      _error = _formatStartError(e);
      notifyListeners();
    }
  }

  /// Builds a user-friendly string for a sync exception thrown out of
  /// `_stt.start()`. The plugin does not have a special "no model for
  /// this locale" exception, so the underlying message can be terse;
  /// translate the common cases.
  String _formatStartError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('language') ||
        lower.contains('locale') ||
        lower.contains('not supported') ||
        lower.contains('not available')) {
      return 'The selected language isn\'t available on this device. '
          'Pick a different language from the list, or install the offline '
          'speech pack in system Settings.';
    }
    if (lower.contains('not enough') || lower.contains('no input')) {
      return 'No microphone is available. Check that a microphone is '
          'connected and not in use by another app.';
    }
    if (lower.contains('permission')) {
      return 'Microphone / speech recognition permission is denied. '
          'Enable it in system Settings.';
    }
    return 'Could not start recognition: $raw';
  }

  /// Stops the active session but keeps what was recognized.
  Future<void> stopListening() async {
    try {
      await _stt.stop();
    } catch (e) {
      // ignore: avoid_print
      print('SpeechService: stop() failed: $e');
    }
    _isListening = false;
    _status = 'idle';
    notifyListeners();
  }

  /// Cancels the active session and discards any in-progress result.
  /// `stts` does not distinguish between stop and cancel; both call
  /// the underlying recognizer's `stop()`. The difference is purely
  /// on the Dart side: we clear the partial text in this case.
  Future<void> cancelListening() async {
    try {
      await _stt.stop();
    } catch (e) {
      // ignore: avoid_print
      print('SpeechService: cancel failed: $e');
    }
    _isListening = false;
    _status = 'idle';
    _lastWords = '';
    notifyListeners();
  }

  /// Clears the recognized text and any pending error.
  void clearText() {
    if (_lastWords.isEmpty && _error == null) return;
    _lastWords = '';
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _resultSub?.cancel();
    unawaited(_stt.dispose());
    super.dispose();
  }
}
