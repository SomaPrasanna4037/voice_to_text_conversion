import 'package:flutter/foundation.dart';


@immutable
class LanguageConfig {
  const LanguageConfig(
    this.code,
    this.bcp47,
    this.sttLocale,
  );
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
final List<LanguageConfig> supportedLanguages = [
  LanguageConfig('bg', 'bg-BG', 'bg_BG'),
  LanguageConfig('cs', 'cs-CZ', 'cs_CZ'),
  LanguageConfig('da', 'da-DK', 'da_DK'),
  LanguageConfig('de', 'de-DE', 'de_DE'),
  LanguageConfig('el', 'el-GR', 'el_GR'),
  LanguageConfig('es', 'es-ES', 'es_ES'),
  LanguageConfig('fi', 'fi-FI', 'fi_FI'),
  LanguageConfig('fr', 'fr-FR', 'fr_FR'),
  LanguageConfig('hu', 'hu-HU', 'hu_HU'),
  LanguageConfig('id-ID', 'id-ID', 'id_ID'),
  LanguageConfig('it', 'it-IT', 'it_IT'),
  LanguageConfig('ja', 'ja-JP', 'ja_JP'),
  LanguageConfig('ko', 'ko-KR', 'ko_KR'),
  LanguageConfig('ms', 'ms-MY', 'ms_MY'),
  LanguageConfig('nb-NO', 'nb-NO', 'nb_NO'),
  LanguageConfig('nl', 'nl-NL', 'nl_NL'),
  LanguageConfig('pl', 'pl-PL', 'pl_PL'),
  LanguageConfig('pt-BR', 'pt-BR', 'pt_BR'),
  LanguageConfig('ro', 'ro-RO', 'ro_RO'),
  LanguageConfig('ru', 'ru-RU', 'ru_RU'),
  LanguageConfig('sv', 'sv-SE', 'sv_SE'),
  LanguageConfig('th', 'th-TH', 'th_TH'),
  LanguageConfig('tr', 'tr-TR', 'tr_TR'),
  LanguageConfig('uk', 'uk-UA', 'uk_UA'),
  LanguageConfig('vi', 'vi-VN', 'vi_VN'),
  LanguageConfig('zh', 'zh-CN', 'zh_CN'),
  LanguageConfig('zh-Hant', 'zh-TW', 'zh_TW'),
  LanguageConfig('hi', 'hi-IN', 'hi_IN'),
  LanguageConfig('pt', 'pt-PT', 'pt_PT'),
  LanguageConfig('en-GB', 'en-GB', 'en_GB'),
  // Rarer on-device support — will likely fall back to cloud automatically
  LanguageConfig('sr-Cyrl', 'sr-RS', null),
  LanguageConfig('lv-LV', 'lv-LV', null),
  LanguageConfig('hr', 'hr-HR', 'hr_HR'),
  LanguageConfig('sl', 'sl-SI', 'sl_SI'),
  // Tamil: limited on-device support on iOS. Better to mark as cloud-only
  // so the UI shows it as network-based. Users can still pick it and use
  // network recognition (on Android it works on-device).
  LanguageConfig('ta', 'ta-IN', 'ta_IN'),
  LanguageConfig('si', 'si-LK', null),
  LanguageConfig('lt-LT', 'lt-LT', 'lt_LT'),
  LanguageConfig('cy-GB', 'cy-GB', null),
  LanguageConfig('et-EE', 'et-EE', null),
  LanguageConfig('fil-PH', 'fil-PH', 'fil_PH'),
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
