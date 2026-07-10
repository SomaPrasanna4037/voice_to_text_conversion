import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'supported_languages.dart';

const Duration _kListenFor = Duration(seconds: 90);

const Duration _kPauseFor = Duration(seconds: 12);

const Duration _kAutoResumeAfter = Duration(milliseconds: 500);

/// After a `cancel()` we wait this long for the platform audio session
/// to fully release before calling `listen()` again. The Android
/// recognizer occasionally throws `error_busy` if you call `listen()`
/// too soon after `cancel()`. iOS needs a longer settle because the
/// `SFSpeechRecognitionTask` callback chain (`didFinishRecognition` +
/// `removeTap` + `audioEngine.stop()` + `setActive(false)`) takes
/// noticeably longer to unwind than the Android equivalent; calling
/// `listen()` while the previous task is still tearing down produces
/// `kLSRErrorDomain Code=300 "Failed to initialize recognizer"`.
const Duration _kPostCancelDelay = Duration(milliseconds: 400);
const Duration _kPostCancelDelayIOS = Duration(milliseconds: 1500);

/// `addsPunctuation` on `SFSpeechAudioBufferRecognitionRequest` (set
/// when the iOS plugin sees `autoPunctuation: true`) requires Apple's
/// server-side speech recognizer. On a device where the user has
/// disabled server-side dictation in Settings → General → Keyboard, or
/// in a region / network condition where Apple's speech server is
/// unreachable, the recognition task fires
/// `kLSRErrorDomain Code=300 "Failed to initialize recognizer"` on
/// the very first callback — same as if the on-device model were
/// missing. Android's `autoPunctuation` flag is honored locally and
/// doesn't have this failure mode, so we keep it on there.
bool get _kAutoPunctuationEnabled => !Platform.isIOS;

const Set<String> _kRecoverableErrors = {
  'error_no_match',
  'error_speech_timeout',
  'error_busy',
  'error_network',
  'error_network_timeout',
  'error_server',
  'error_server_disconnected',
  'error_too_many_requests',
};

/// `errorMsg` strings that *are* truly fatal — the recognizer is in a
/// state that will keep failing until we swap the whole instance.
const Set<String> _kFatalErrors = {
  'error_unknown',
  'error_audio_error',
  'error_client',
  'error_permission',
  'error_language_not_supported',
  'error_language_unavailable',
};

const Set<String> _kLocaleUnavailableErrors = {
  'error_assets_not_installed',
  'error_listen_failed',
};
String _normalizeErrorMsg(String msg) {
  final paren = msg.indexOf(' (');
  if (paren > 0 && msg.endsWith(')')) return msg.substring(0, paren);
  return msg;
}

/// Wraps the [SpeechToText] plugin and exposes its state via [ChangeNotifier].
///
/// The page and its widgets only talk to this service, so they stay
/// stateless and easy to read.
class SpeechService extends ChangeNotifier {
  SpeechService({SpeechToText? speechToText})
    : _speech = speechToText ?? SpeechToText();

  // Non-final so we can swap in a fresh instance after a permanent error
  // (the plugin only honors `onStatus`/`onError` from the first initialize).
  SpeechToText _speech;

  bool _isAvailable = false;
  bool _isListening = false;
  String _lastWords = '';
  String _status = '';
  String? _error;

  /// The curated, user-facing list of languages this app supports,
  /// annotated with whether each one is actually installed on the device.
  List<LanguageEntry> _languages = const [];

  /// Locales the device's recognizer reports in `speech.locales()` that
  /// do NOT match any curated [LanguageConfig.sttLocale] (in either
  /// underscore or hyphen form). These are shown at the bottom of the
  /// dropdown as a read-only "Default locales" section so the user can
  /// see what's installed but not curated.
  List<LocaleName> _unmatchedDeviceLocales = const [];

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

  /// Locales the device's recognizer reports in `speech.locales()` that
  /// do NOT match any curated [LanguageConfig.sttLocale] (in either
  /// underscore or hyphen form). These are shown at the bottom of the
  /// dropdown as a read-only "Default locales" section.
  List<LocaleName> get unmatchedDeviceLocales => _unmatchedDeviceLocales;

  /// The BCP-47 tag of the currently selected language (the value we
  /// actually hand to `SpeechListenOptions.localeId`). `null` if
  /// nothing is selected. Falls back to the user-picked device-only
  /// locale id when no curated entry is selected.
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
  /// Currently disabled — the app always uses the system default language.
  bool get canChangeLocale => false;

  /// True when the user is expected to be speaking (or audio is being
  /// played into the mic). Used by the UI to show the right hint.
  bool _userInitiatedSession = false;

  /// Initializes the underlying recognizer and loads available locales.
  Future<void> initialize() async {
    final available = await _speech.initialize(
      onStatus: _handleStatus,
      onError: _handleError,
    );

    _isAvailable = available;
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
    final deviceLocales = await _speech.locales();
    final systemLocale = await _speech.systemLocale();

    _languages = _buildEntries(deviceLocales);
    _unmatchedDeviceLocales = _computeUnmatchedDeviceLocales(deviceLocales);

    // Always use the system default language. Don't allow user selection.
    _selectedDeviceLocaleId = null;
    _selectedCode = _resolveDefaultCode(
      _languages,
      null, // Ignore any previously selected code, always use system
      systemLocale?.localeId,
    );
  }

  /// Returns the subset of [deviceLocales] whose `localeId` doesn't
  /// match any curated [LanguageConfig.sttLocale] in either the
  /// underscore or hyphen form. The current default locale is moved to
  /// the front of the list (the plugin already does this) so the
  /// "Default locales" section is consistent with what the plugin
  /// reports.
  List<LocaleName> _computeUnmatchedDeviceLocales(
    List<LocaleName> deviceLocales,
  ) {
    // Build the set of canonical ids we already curate, in both forms.
    final curatedIds = <String>{};
    for (final cfg in supportedLanguages) {
      final stt = cfg.sttLocale;
      if (stt == null) continue;
      curatedIds.add(stt);
      curatedIds.add(stt.replaceAll('_', '-'));
    }

    bool isCurated(String id) {
      if (curatedIds.contains(id)) return true;
      // Also try the other form (curated list is in underscore form, so
      // if `id` is hyphen form, convert it).
      final alt = id.contains('-')
          ? id.replaceAll('-', '_')
          : id.replaceAll('_', '-');
      return curatedIds.contains(alt);
    }

    return [
      for (final l in deviceLocales)
        if (!isCurated(l.localeId)) l,
    ];
  }

  /// Cross-references [supportedLanguages] with the locales the device's
  /// recognizer actually has. The plugin reports ids in different
  /// formats on different platforms:
  ///
  ///   - Android: `{lang}_{COUNTRY}` (e.g. `ta_IN`, `en_GB`)
  ///   - iOS:     BCP-47 with hyphens (e.g. `ta-IN`, `en-GB`)
  ///
  /// The curated `sttLocale` is in underscore form, so we also try the
  /// hyphen form when looking for a match on iOS. (The curated config
  /// is the single source of truth — we don't do fuzzy base-language
  /// matching here.)
  List<LanguageEntry> _buildEntries(List<LocaleName> deviceLocales) {
    final deviceIds = deviceLocales.map((l) => l.localeId).toSet();
    bool deviceHas(String? curated) {
      if (curated == null) return false;
      if (deviceIds.contains(curated)) return true;
      // iOS: try the BCP-47 hyphen form (`ta_IN` -> `ta-IN`).
      final hyphen = curated.replaceAll('_', '-');
      if (deviceIds.contains(hyphen)) return true;
      return false;
    }

    return [
      for (final cfg in supportedLanguages)
        LanguageEntry(
          config: cfg,
          isAvailable: deviceHas(cfg.sttLocale),
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
  /// user's current choice, then the system locale (if any curated entry
  /// matches it), then the first available curated language, and finally
  /// the first entry that matches `en-GB`/`en` (or just the first entry).
  String? _resolveDefaultCode(
    List<LanguageEntry> entries,
    String? currentCode,
    String? systemLocaleId,
  ) {
    String? pickFirstAvailable(Iterable<String> codes) {
      for (final code in codes) {
        final match = _findByCode(code);
        if (match != null && match.isAvailable) return match.config.code;
      }
      return null;
    }

    if (currentCode != null) {
      final current = _findByCode(currentCode);
      if (current != null && current.isAvailable) return current.config.code;
    }

    if (systemLocaleId != null) {
      // The system reports ids in either form (`en-GB` or `en_GB`); the
      // curated list uses `bcp47` (hyphens) and `sttLocale` (underscores).
      // Try to find a curated entry whose bcp47 matches either form,
      // and whose entry is actually available on this device.
      final code = _matchCuratedByBcp47(systemLocaleId, entries);
      if (code != null) return code;
    }

    final firstAvailable = entries
        .where((e) => e.isAvailable)
        .map((e) => e.config.code);
    final fallback = pickFirstAvailable(firstAvailable);
    if (fallback != null) return fallback;

    // Last resort: nothing is available on the device. We deliberately
    // return `null` here so the dropdown can show its "No languages
    // available" hint instead of selecting an unavailable code (which
    // would crash the DropdownButton assertion because the matching
    // item is disabled and has `value: null`).
    return null;
  }

  /// Returns the [LanguageConfig.code] of the curated entry whose
  /// [LanguageConfig.bcp47] matches [systemLocaleId] in either the
  /// hyphen or underscore form AND whose [LanguageEntry.isAvailable]
  /// is `true` in the supplied [entries]. Returns `null` if nothing
  /// matches.
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

    final hyphen = systemLocaleId.replaceAll('_', '-');
    final underscore = systemLocaleId.replaceAll('-', '_');
    for (final cfg in supportedLanguages) {
      if (cfg.bcp47 == hyphen || cfg.bcp47 == underscore) {
        if (isAvailableFor(cfg) == true) return cfg.code;
      }
    }
    // Last-ditch: match by base language only (e.g. system `en_US` ->
    // curated `en-GB`/`en`). Prefer longer/more specific matches first by
    // walking the curated list in order, then falling back to a base match.
    final base = systemLocaleId.split(RegExp('[-_]')).first;
    for (final cfg in supportedLanguages) {
      final cfgBase = cfg.bcp47.split(RegExp('[-_]')).first;
      if (cfgBase == base && isAvailableFor(cfg) == true) return cfg.code;
    }
    return null;
  }

  void _handleStatus(String status) {
    _status = status;
    _isListening = _speech.isListening;
    notifyListeners();
  }

  void _handleError(Object error) {
    final formatted = _formatError(error);
    // Also log to the console so it's easy to find in `flutter logs`.
    // ignore: avoid_print
    print('SpeechService error: $formatted');
    _isListening = _speech.isListening;
    notifyListeners();

    // Extract the raw `errorMsg` (e.g. `error_no_match`). The Android
    // plugin marks *every* error as `permanent: true`, so we can't trust
    // that flag — we look at the message instead. We also strip the
    // trailing `(N)` numeric code the iOS plugin appends to unknown
    // errors (`error_unknown (300)`, `error_unknown (1100)`, ...) so
    // the comparison against the bare token sets below still works.
    final rawMsg = error is SpeechRecognitionError ? error.errorMsg : null;
    final msg = rawMsg == null ? null : _normalizeErrorMsg(rawMsg);

    // If the user has picked a locale that isn't actually installed on
    // this device (a "Not installed" / "Cloud only" / "Default locales"
    // entry), the recognizer may surface a fatal-looking error like
    // `error_unknown` or `error_language_not_supported`. Reinitializing
    // the recognizer won't help — the *user's selection* is the problem.
    // So stop the session, surface a friendly error, and don't auto-
    // resume.
    final pickedLocaleIsUnrecognized = _currentPickIsUnrecognized();

    // iOS-specific "no model for this locale" errors. These are
    // *fatal-looking* but they're really about the user's locale pick
    // (or the system's missing offline pack), not a broken recognizer
    // state. Surface the same "language not available" hint that the
    // `pickedLocaleIsUnrecognized` branch would and don't reinit.
    if (msg != null && _kLocaleUnavailableErrors.contains(msg)) {
      _userInitiatedSession = false;
      _isListening = false;
      _error =
          'The selected language isn\'t available on this device. '
          'Pick a different language from the list, or install the '
          'offline speech pack in system Settings.';
      notifyListeners();
      return;
    }

    if (msg != null &&
        _kFatalErrors.contains(msg) &&
        !pickedLocaleIsUnrecognized) {
      // On iOS, `error_unknown` is overwhelmingly caused by a fresh
      // `SFSpeechRecognitionTask` being created while the previous one
      // is still tearing down (`kLSRErrorDomain Code=300 "Failed to
      // initialize recognizer"`) or by `addsPunctuation: true` forcing
      // a server-side path that the device can't reach. The recognizer
      // is *not* in a permanently broken state — a fresh
      // `SpeechToText` instance would just hit the same kLSRError
      // because the underlying model/asset hasn't changed. So: do NOT
      // reinit. Just stop the session, surface the error, and let the
      // user retry. The user-initiated retry will use the longer
      // iOS-tuned post-cancel delay and (with the `autoPunctuation`
      // fix above) will succeed if the device's recognizer is healthy.
      // On Android, `error_unknown` is a genuine fatal — keep the
      // reinit for that platform.
      if (Platform.isIOS && msg == 'error_unknown') {
        _userInitiatedSession = false;
        _isListening = false;
        _error = pickedLocaleIsUnrecognized
            ? 'The selected language isn\'t available on this device. '
                  'Pick a different language from the list, or install the '
                  'offline speech pack in system Settings.'
            : formatted;
        notifyListeners();
        return;
      }
      // Truly fatal AND the recognizer is in a bad state (not just the
      // user's locale choice). Reinitialize with a fresh recognizer.
      _error = formatted;
      notifyListeners();
      _reinitialize();
      return;
    }

    if (msg != null && _kRecoverableErrors.contains(msg)) {
      // Don't show these in the UI — they happen on every short silence
      // and would just flash an error banner constantly. Keep the last
      // recognized text and quietly restart the session if the user
      // hasn't stopped listening.
      _error = null;
      notifyListeners();
      if (_userInitiatedSession) {
        // Defer slightly so we don't fight the recognizer's own teardown.
        Future<void>.delayed(_kAutoResumeAfter, _autoResumeListening);
      }
      return;
    }

    // Either:
    //   - a fatal error AND the picked locale is unrecognized, or
    //   - an unknown error message.
    // In both cases: surface the error, stop the session, and don't
    // auto-resume. If the locale choice is the issue, a reinit would
    // just hit the same wall.
    _userInitiatedSession = false;
    _isListening = false;
    _error = pickedLocaleIsUnrecognized
        ? 'The selected language isn\'t available on this device. '
              'Pick a different language from the list, or install the '
              'offline speech pack in system Settings.'
        : formatted;
    notifyListeners();
  }

  /// Returns true if the user's current pick (curated or device-locale)
  /// is for a language the device's recognizer doesn't have on-device.
  /// Used to decide whether a fatal-looking error from the recognizer
  /// is really about the user's selection (don't reinit) vs. a broken
  /// recognizer state (do reinit).
  bool _currentPickIsUnrecognized() {
    if (_selectedCode != null) {
      final entry = _findByCode(_selectedCode!);
      if (entry == null) return true; // unknown code
      // Cloud-only entries are *expected* to fail on-device; treat them
      // as unrecognized for the reinit decision.
      if (entry.isCloudOnly) return true;
      if (!entry.isAvailable) return true;
      return false;
    }
    if (_selectedDeviceLocaleId != null) {
      // The "Default locales" section is device-only and already passed
      // the `isUnmatched` check in `selectDeviceLocale`, so the device
      // should have it. But if the recognizer still complains, treat
      // it as a real error (let the reinit path run).
      return false;
    }
    // No selection at all — let the reinit path handle it as a
    // recognizer state issue.
    return false;
  }

  /// Starts a fresh `listen()` on the same recognizer, preserving the
  /// current language. Used to recover from transient errors like
  /// `error_no_match` without forcing the user to tap the mic again.
  Future<void> _autoResumeListening() async {
    if (!_isAvailable) return;
    if (!_userInitiatedSession) return;
    if (_isListening) return;
    // If the user has already pressed the mic button to stop, bail.
    if (_selectedCode == null && _selectedDeviceLocaleId == null) return;

    try {
      await _speech.listen(
        onResult: _handleResult,
        listenOptions: SpeechListenOptions(
          cancelOnError: false, // don't bail on every recoverable hiccup
          partialResults: true,
          autoPunctuation: _kAutoPunctuationEnabled,
          localeId: selectedBcp47,
          listenMode: ListenMode.dictation,
          listenFor: _kListenFor,
          pauseFor: _kPauseFor,
        ),
      );
      _isListening = _speech.isListening;
      notifyListeners();
    } catch (e) {
      // iOS can throw `ListenFailedException` synchronously from
      // `listen()` when the recognizer can't be created (e.g. the
      // device has no on-device model for the chosen locale and we're
      // not on the network). Treat the same as `startListening`:
      // surface the error and stop trying to auto-resume.
      // ignore: avoid_print
      print('SpeechService: auto-resume failed: $e');
      _userInitiatedSession = false;
      _error = _formatError(e);
      _isListening = false;
      notifyListeners();
    }
  }

  /// Builds a new [SpeechToText] and re-initializes it. The previous
  /// instance is discarded so its broken state can't be reused.
  ///
  /// Only effective on Android. On iOS we deliberately do *not* call
  /// this — see the iOS branch in `_handleError`. A fresh
  /// `SpeechToText` instance on iOS means a fresh
  /// `SpeechToTextPlugin`, a fresh `SFSpeechRecognizer`, and a fresh
  /// `setupRecognizerForLocale(Locale.current)` call. If the underlying
  /// on-device asset is the problem (the common cause of
  /// `kLSRErrorDomain Code=300 "Failed to initialize recognizer"`),
  /// a fresh plugin instance hits the same failure. The
  /// `setupRecognizerForLocale` call also picks `Locale.current` (the
  /// device language), discarding the user's locale preference until
  /// the next `listen()` swaps it back — which is when the failure
  /// usually recurs.
  Future<void> _reinitialize() async {
    if (Platform.isIOS) {
      // ignore: avoid_print
      print(
        'SpeechService: iOS re-init skipped (would re-trigger '
        'kLSRErrorDomain); user must retry',
      );
      return;
    }
    try {
      // ignore: avoid_print
      print('SpeechService: permanent error, re-initializing recognizer');
      final fresh = SpeechToText();
      final available = await fresh.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: true,
      );
      _speech = fresh;
      _isAvailable = available;
      _isListening = false;
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print('SpeechService: re-initialization failed: $e');
    }
  }

  /// Turns a raw [SpeechRecognitionError] (or anything else) into a readable
  /// string. The default `toString()` only renders the class name, which
  /// hides the actual `errorMsg` and `permanent` fields.
  String _formatError(Object error) {
    if (error is SpeechRecognitionError) {
      final pickedUnrecognized = _currentPickIsUnrecognized();
      // The iOS plugin appends a numeric code in parentheses to
      // unknown-class errors (`error_unknown (300)`, etc.) — normalize
      // so the switch below matches. We keep the original `errorMsg`
      // for the banner text so the user can still see the underlying
      // SFSpeechError code if they need to debug.
      final rawMsg = error.errorMsg;
      final msg = _normalizeErrorMsg(rawMsg);
      final hint = switch (msg) {
        'error_no_match' =>
          'The recognizer heard audio but could not match it to any '
              'words. This often happens with TTS playback — try speaking '
              'naturally instead, or play the audio louder / closer to '
              'the mic.',
        'error_speech_timeout' =>
          'No speech was detected for a while. Check that the device '
              'microphone is unmuted and the audio source is loud enough.',
        'error_network' || 'error_network_timeout' =>
          'Network recognition failed. Check the device\'s internet '
              'connection.',
        'error_busy' => 'The recognizer was busy. Retried automatically.',
        'error_permission' =>
          'Microphone permission is denied. Enable it in system Settings.',
        // iOS: the device has no on-device model for the chosen locale
        // and we couldn't get one from the network. (Android surfaces
        // `error_language_not_supported` / `error_language_unavailable`
        // for the same condition.)
        'error_assets_not_installed' =>
          'The selected language isn\'t available on this device. '
              'Pick a different language from the list, or install the '
              'offline speech pack in system Settings.',
        'error_language_not_supported' || 'error_language_unavailable' =>
          'The selected recognition language isn\'t available on this '
              'device. Try a different language or install the offline pack.',
        'error_audio_error' =>
          'There was a problem with the audio input. Check that no '
              'other app is using the microphone.',
        // `error_unknown` (300 / 1100 / 1107 / ...) on iOS is what
        // `SFSpeechRecognizer` throws for a grab-bag of "I can't
        // recognize" cases. The single most common trigger in practice
        // is a locale the recognizer can't handle. If the user's pick
        // is one of our not-installed / cloud-only entries, surface a
        // useful hint rather than a bare code.
        'error_unknown' =>
          pickedUnrecognized
              ? 'The selected language isn\'t available on this device. '
                    'Pick a different language from the list, or install the '
                    'offline speech pack in system Settings.'
              : 'The recognizer stopped unexpectedly. This can happen with '
                    'very short / silent audio or right after the system '
                    'tries to take over the audio session. Try again.',
        _ => null,
      };
      final base = 'Recognition error ($rawMsg)';
      if (hint != null) return '$base\n$hint';
      return base;
    }
    return error.toString();
  }

  void _handleResult(SpeechRecognitionResult result) {
    _lastWords = result.recognizedWords;
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
  /// currently be reported by `speech.locales()` and not match any
  /// curated entry (i.e. it must be in [unmatchedDeviceLocales]).
  /// Clears any pending curated selection.
  void selectDeviceLocale(String localeId) {
    if (localeId == _selectedDeviceLocaleId && _selectedCode == null) return;
    final isUnmatched = _unmatchedDeviceLocales.any(
      (l) => l.localeId == localeId,
    );
    if (!isUnmatched) return;
    _selectedCode = null;
    _selectedDeviceLocaleId = localeId;
    notifyListeners();
  }

  /// Starts a new recognition session.
  ///
  /// Defensively cancels any stale session and waits briefly before
  /// `listen()` to let the platform audio session settle (the plugin docs
  /// recommend this when interacting with other audio plugins, and it also
  /// helps when the previous session errored out).
  ///
  /// On iOS, the plugin's `listen()` can throw `ListenFailedException`
  /// synchronously when the platform can't create the recognizer for the
  /// chosen locale (e.g. the device has no on-device model and there's
  /// no network). We catch that, surface a friendly error, and stop the
  /// session — the user can pick a different language and try again.
  Future<void> startListening() async {
    if (!_isAvailable) {
      _error = 'Speech recognition is not available on this device.';
      notifyListeners();
      return;
    }
    _error = null;
    _userInitiatedSession = true;
    notifyListeners();

    // Clear any stale native state from a previous (possibly failed) session.
    try {
      await _speech.cancel();
    } catch (_) {
      // ignore: cancel failures – we just want a clean slate
    }
    // iOS's `SFSpeechRecognitionTask` needs a noticeably longer settle
    // than Android's `SpeechRecognizer` before the next `listen()` can
    // safely create a new task on the same recognizer. See the comment
    // on `_kPostCancelDelayIOS`.
    await Future<void>.delayed(
      Platform.isIOS ? _kPostCancelDelayIOS : _kPostCancelDelay,
    );

    try {
      await _speech.listen(
        onResult: _handleResult,
        listenOptions: SpeechListenOptions(
          // Don't tear down the session on every recoverable error — we
          // handle those ourselves in `_handleError` and auto-restart.
          cancelOnError: false,
          partialResults: true,
          // Disable autoPunctuation on iOS when the selected locale might
          // not have reliable on-device support (e.g. Tamil, other rare
          // languages). When autoPunctuation is enabled, iOS requires the
          // server-side path, which fails faster with a clear error. By
          // disabling it, we give the on-device fallback path a better
          // chance to work.
          autoPunctuation: _shouldEnableAutoPunctuation(),
          localeId: selectedBcp47,
          listenMode: ListenMode.dictation,
          listenFor: _kListenFor,
          pauseFor: _kPauseFor,
        ),
      );
      _isListening = _speech.isListening;
      notifyListeners();
    } catch (e) {
      // iOS throws `ListenFailedException` when the recognizer can't
      // be created for the chosen locale. We don't reinit (reinit
      // with the same locale will fail the same way) — just stop the
      // session and surface the error so the user can pick a
      // different language.
      _userInitiatedSession = false;
      _isListening = false;
      _error = _formatStartError(e);
      notifyListeners();
    }
  }

  /// Whether to enable autoPunctuation for the current locale.
  /// Disabled for locales with limited on-device support on iOS.
  bool _shouldEnableAutoPunctuation() {
    if (!Platform.isIOS) return _kAutoPunctuationEnabled;
    
    // On iOS, languages with limited on-device models should not enable
    // autoPunctuation because it forces the server-side path. When that
    // fails, the error is immediate and confusing. Better to let the
    // on-device path try first (even if it falls back to network).
    if (selectedBcp47 == null) return false;
    
    final rareOnIOS = {
      'ta-IN', 'ta_IN', // Tamil — limited on-device support
      'hi-Latn', 'hi_Latn', // Hindi Transliteration
      'hi-IN-translit', 'hi_IN_translit',
      'wuu-CN', 'wuu_CN', // Wu Chinese
      'yue-CN', 'yue_CN', // Cantonese
    };
    
    return !rareOnIOS.contains(selectedBcp47);
  }

  /// Builds a user-friendly string for a sync exception thrown out of
  /// `_speech.listen()`. The most common case on iOS is
  /// `ListenFailedException` which doesn't have a message property.
  /// We use context-aware error detection based on the selected language.
  String _formatStartError(Object error) {
    String raw = error.toString();
    
    // Try to extract message from PlatformException if available
    if (error is PlatformException) {
      if (error.message != null && error.message!.isNotEmpty) {
        raw = error.message!;
      } else if (error.code.isNotEmpty) {
        raw = error.code;
      }
    }
    
    // iOS ListenFailedException typically has no message (just class name).
    // Use context-aware detection: check if the selected language is known
    // to have limited iOS support.
    final hasMessageDetail = !raw.startsWith('Instance of');
    final isRareLanguageOnIOS = _selectedCode != null && 
        _isRareLanguageOnIOS(_selectedCode!);
    
    if (!hasMessageDetail && isRareLanguageOnIOS) {
      // ListenFailedException with no message, on a rare language → almost
      // certainly a language availability issue.
      return 'The selected language isn\'t available on this device. '
          'Pick a different language from the list, or install the offline '
          'speech pack in system Settings.';
    }
    
    // For languages with unknown iOS support, we can't be sure if it's the
    // language or the recognizer, so give a more generic error.
    if (!hasMessageDetail) {
      return 'Could not initialize speech recognition for the selected '
          'language. Try a different language or reconnect the microphone.';
    }
    
    // If we DO have a message, try to parse it.
    final normalized = _normalizeErrorMsg(raw);
    
    // Check for explicit error patterns
    if (raw.contains('Failed to create speech recognizer') ||
        raw.contains('on device recognition is not supported') ||
        raw.contains('error_listen_failed') ||
        raw.contains('error_assets_not_installed') ||
        normalized.contains('error_language_not_supported') ||
        normalized.contains('error_language_unavailable')) {
      return 'The selected language isn\'t available on this device. '
          'Pick a different language from the list, or install the offline '
          'speech pack in system Settings.';
    }
    if (raw.contains('Not enough available inputs') ||
        raw.contains('microphone') ||
        raw.contains('input')) {
      return 'No microphone is available. Check that a microphone is '
          'connected and not in use by another app.';
    }
    return 'Could not start recognition: $raw';
  }

  /// Returns true if the currently selected language is known to have
  /// limited on-device support on iOS.
  bool _isRareLanguageOnIOS(String? code) {
    if (!Platform.isIOS || code == null) return false;
    
    final entry = _findByCode(code);
    if (entry == null) return false;
    
    // Languages with weak iOS on-device support:
    // - Tamil: no on-device model on most iOS versions
    // - Hindi variants: limited support
    // - Wu/Cantonese: limited support
    final rareOnIOS = {
      'ta', // Tamil
      'ta_IN',
      'hi', // Hindi
      'hi-Latn',
      'hi-IN-translit',
      'wuu-CN', // Wu Chinese
      'yue-CN', // Cantonese
    };
    
    final configId = entry.config.code;
    final configBcp47 = entry.config.bcp47;
    
    return rareOnIOS.contains(configId) || rareOnIOS.contains(configBcp47);
  }

  /// Stops the active session but keeps what was recognized.
  Future<void> stopListening() async {
    _userInitiatedSession = false;
    await _speech.stop();
    _isListening = _speech.isListening;
    notifyListeners();
  }

  /// Cancels the active session and discards any in-progress result.
  Future<void> cancelListening() async {
    _userInitiatedSession = false;
    await _speech.cancel();
    _isListening = _speech.isListening;
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

  /// Debug method: Calls the native Android code to log RecognitionSupport
  /// details directly. Check logcat with tag 'SpeechDebug' for the output.
  /// Only works on Android API 33+ with on-device speech recognition available.
  Future<String> debugRecognitionSupport() async {
    if (!Platform.isAndroid) {
      return 'Debug: Only available on Android';
    }
    try {
      const channel = MethodChannel('voice_to_text_conversion/speech_debug');
      final result = await channel.invokeMethod<String>('debugRecognitionSupport');
      return result ?? 'Debug: No result';
    } on PlatformException catch (e) {
      return 'Debug error: ${e.message}';
    }
  }
}
