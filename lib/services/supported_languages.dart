import 'package:flutter/foundation.dart';


@immutable
class LanguageConfig {
  /// All curated entries. Pass [sttLocale] explicitly for the few
  /// languages the plugin reports as on-device available (BCP-47 hyphen
  /// form, e.g. `"en-US"`); leave it `null` for cloud-only entries.
  const LanguageConfig(
    this.code,
    this.bcp47, {
    this.sttLocale,
  });
  final String code;
  final String bcp47;
  final String? sttLocale;

  @override
  bool operator ==(Object other) =>
      other is LanguageConfig &&
      other.code == code &&
      other.bcp47 == bcp47 &&
      other.sttLocale == sttLocale;

  @override
  int get hashCode => Object.hash(code, bcp47, sttLocale);
}

/// Curated list of recognition languages this app advertises in its UI.
///
/// `stts` exposes a flat list of supported language ids from
/// `Stt.getLanguages()` (BCP-47, hyphen form, e.g. `"en-US"`, `"ta-IN"`,
/// `"zh-Hant"`). The plugin does not give us a display name per id, so the
/// curated [LanguageConfig.code] is used for display and `bcp47` is what
/// we hand to `Stt.setLanguage(...)`. We rely on this single source of
/// truth for matching against the device-reported id and for the
/// dropdown UI.
///
/// For languages the plugin never pre-installs but can still recognise
/// over the network, leave [LanguageConfig.sttLocale] `null`. The
/// recognizer will surface a clear error if it really cannot handle the
/// language.
final List<LanguageConfig> supportedLanguages = [
  LanguageConfig('bg', 'bg-BG', sttLocale: 'bg-BG'),
  LanguageConfig('cs', 'cs-CZ', sttLocale: 'cs-CZ'),
  LanguageConfig('da', 'da-DK', sttLocale: 'da-DK'),
  LanguageConfig('de', 'de-DE', sttLocale: 'de-DE'),
  LanguageConfig('el', 'el-GR', sttLocale: 'el-GR'),
  LanguageConfig('es', 'es-ES', sttLocale: 'es-ES'),
  LanguageConfig('fi', 'fi-FI', sttLocale: 'fi-FI'),
  LanguageConfig('fr', 'fr-FR', sttLocale: 'fr-FR'),
  LanguageConfig('hu', 'hu-HU', sttLocale: 'hu-HU'),
  LanguageConfig('id-ID', 'id-ID', sttLocale: 'id-ID'),
  LanguageConfig('it', 'it-IT', sttLocale: 'it-IT'),
  LanguageConfig('ja', 'ja-JP', sttLocale: 'ja-JP'),
  LanguageConfig('ko', 'ko-KR', sttLocale: 'ko-KR'),
  LanguageConfig('ms', 'ms-MY', sttLocale: 'ms-MY'),
  LanguageConfig('nb-NO', 'nb-NO', sttLocale: 'nb-NO'),
  LanguageConfig('nl', 'nl-NL', sttLocale: 'nl-NL'),
  LanguageConfig('pl', 'pl-PL', sttLocale: 'pl-PL'),
  LanguageConfig('pt-BR', 'pt-BR', sttLocale: 'pt-BR'),
  LanguageConfig('ro', 'ro-RO', sttLocale: 'ro-RO'),
  LanguageConfig('ru', 'ru-RU', sttLocale: 'ru-RU'),
  LanguageConfig('sv', 'sv-SE', sttLocale: 'sv-SE'),
  LanguageConfig('th', 'th-TH', sttLocale: 'th-TH'),
  LanguageConfig('tr', 'tr-TR', sttLocale: 'tr-TR'),
  LanguageConfig('uk', 'uk-UA', sttLocale: 'uk-UA'),
  LanguageConfig('vi', 'vi-VN', sttLocale: 'vi-VN'),
  LanguageConfig('zh', 'zh-CN', sttLocale: 'zh-CN'),
  LanguageConfig('zh-Hant', 'zh-TW', sttLocale: 'zh-TW'),
  LanguageConfig('hi', 'hi-IN', sttLocale: 'hi-IN'),
  LanguageConfig('pt', 'pt-PT', sttLocale: 'pt-PT'),
  LanguageConfig('en-GB', 'en-GB', sttLocale: 'en-GB'),
  // Rarer on-device support — these are typically not pre-installed and
  // may fall back to the network when no offline model is available.
  LanguageConfig('sr-Cyrl', 'sr-RS', sttLocale: 'sr-RS'),
  LanguageConfig('lv-LV', 'lv-LV', sttLocale: 'lv-LV'),
  LanguageConfig('hr', 'hr-HR', sttLocale: 'hr-HR'),
  LanguageConfig('sl', 'sl-SI', sttLocale: 'sl-SI'),
  LanguageConfig('ta', 'ta-IN', sttLocale: 'ta-IN'),
  LanguageConfig('si', 'si-LK', sttLocale: 'si-LK'),
  LanguageConfig('lt-LT', 'lt-LT', sttLocale: 'lt-LT'),
  LanguageConfig('cy-GB', 'cy-GB', sttLocale: 'cy-GB'),
  LanguageConfig('et-EE', 'et-EE', sttLocale: 'et-EE'),
  LanguageConfig('fil-PH', 'fil-PH', sttLocale: 'fil-PH'),
];

@immutable
class LanguageEntry {
  const LanguageEntry({
    required this.config,
    required this.isAvailable,
    required this.isCloudOnly,
  });

  final LanguageConfig config;
  final bool isAvailable;
  final bool isCloudOnly;

  bool get isSelectable => isAvailable;

  @override
  bool operator ==(Object other) =>
      other is LanguageEntry &&
      other.config == config &&
      other.isAvailable == isAvailable &&
      other.isCloudOnly == isCloudOnly;

  @override
  int get hashCode => Object.hash(config, isAvailable, isCloudOnly);
}
