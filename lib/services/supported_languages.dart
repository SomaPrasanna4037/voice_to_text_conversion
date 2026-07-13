import 'package:flutter/foundation.dart';

/// One entry in the language dropdown. `code` is the value used for
/// both the dropdown's [DropdownMenuItem.value] and the value handed
/// to `TranscribeRequest.language` (either `"auto"` or a Whisper
/// canonical subtag like `"en"`, `"fr"`, `"ta"`, …).
@immutable
class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.displayName,
  });

  final String code;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is LanguageOption && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// All 99 languages that OpenAI Whisper supports, taken directly
/// from the upstream `whisper/tokenizer.py` `LANGUAGES` map.
///
/// The first entry is the sentinel `"auto"` which tells Whisper to
/// auto-detect the spoken language. The remaining 99 entries are
/// the canonical ISO 639-1 subtags (with a few regional exceptions
/// like `yue` Cantonese and `haw` Hawaiian) Whisper accepts in its
/// `language` parameter.
///
/// Important:
///   - Whisper does **not** take BCP-47 tags with region (e.g.
///     `ta-IN`, `en-GB`). Use the bare canonical subtag (`ta`,
///     `en`). Passing a regional tag will be rejected by whisper_kit
///     or silently treated as a different language.
///   - `no` is Norwegian (Bokmål) in Whisper. There is no separate
///     entry for Nynorsk in the upstream list — pass `no` for both.
///   - The display name is purely cosmetic. If you change a display
///     name, the value the recognizer actually receives is
///     [LanguageOption.code].
///
/// Source: https://github.com/openai/whisper/blob/main/whisper/tokenizer.py
const List<LanguageOption> supportedLanguages = [
  // Sentinel for "let Whisper decide".
  LanguageOption(code: 'auto', displayName: 'Auto-detect'),

  // The full 99-language set, alphabetical.
  LanguageOption(code: 'af', displayName: 'Afrikaans'),
  LanguageOption(code: 'am', displayName: 'Amharic'),
  LanguageOption(code: 'ar', displayName: 'Arabic'),
  LanguageOption(code: 'as', displayName: 'Assamese'),
  LanguageOption(code: 'az', displayName: 'Azerbaijani'),
  LanguageOption(code: 'ba', displayName: 'Bashkir'),
  LanguageOption(code: 'be', displayName: 'Belarusian'),
  LanguageOption(code: 'bg', displayName: 'Bulgarian'),
  LanguageOption(code: 'bn', displayName: 'Bengali'),
  LanguageOption(code: 'bo', displayName: 'Tibetan'),
  LanguageOption(code: 'br', displayName: 'Breton'),
  LanguageOption(code: 'bs', displayName: 'Bosnian'),
  LanguageOption(code: 'ca', displayName: 'Catalan'),
  LanguageOption(code: 'cs', displayName: 'Czech'),
  LanguageOption(code: 'cy', displayName: 'Welsh'),
  LanguageOption(code: 'da', displayName: 'Danish'),
  LanguageOption(code: 'de', displayName: 'German'),
  LanguageOption(code: 'el', displayName: 'Greek'),
  LanguageOption(code: 'en', displayName: 'English'),
  LanguageOption(code: 'es', displayName: 'Spanish'),
  LanguageOption(code: 'et', displayName: 'Estonian'),
  LanguageOption(code: 'eu', displayName: 'Basque'),
  LanguageOption(code: 'fa', displayName: 'Persian'),
  LanguageOption(code: 'fi', displayName: 'Finnish'),
  LanguageOption(code: 'fo', displayName: 'Faroese'),
  LanguageOption(code: 'fr', displayName: 'French'),
  LanguageOption(code: 'gl', displayName: 'Galician'),
  LanguageOption(code: 'gu', displayName: 'Gujarati'),
  LanguageOption(code: 'ha', displayName: 'Hausa'),
  LanguageOption(code: 'haw', displayName: 'Hawaiian'),
  LanguageOption(code: 'he', displayName: 'Hebrew'),
  LanguageOption(code: 'hi', displayName: 'Hindi'),
  LanguageOption(code: 'hr', displayName: 'Croatian'),
  LanguageOption(code: 'ht', displayName: 'Haitian Creole'),
  LanguageOption(code: 'hu', displayName: 'Hungarian'),
  LanguageOption(code: 'hy', displayName: 'Armenian'),
  LanguageOption(code: 'id', displayName: 'Indonesian'),
  LanguageOption(code: 'is', displayName: 'Icelandic'),
  LanguageOption(code: 'it', displayName: 'Italian'),
  LanguageOption(code: 'ja', displayName: 'Japanese'),
  LanguageOption(code: 'jw', displayName: 'Javanese'),
  LanguageOption(code: 'ka', displayName: 'Georgian'),
  LanguageOption(code: 'kk', displayName: 'Kazakh'),
  LanguageOption(code: 'km', displayName: 'Khmer'),
  LanguageOption(code: 'kn', displayName: 'Kannada'),
  LanguageOption(code: 'ko', displayName: 'Korean'),
  LanguageOption(code: 'la', displayName: 'Latin'),
  LanguageOption(code: 'lb', displayName: 'Luxembourgish'),
  LanguageOption(code: 'ln', displayName: 'Lingala'),
  LanguageOption(code: 'lo', displayName: 'Lao'),
  LanguageOption(code: 'lt', displayName: 'Lithuanian'),
  LanguageOption(code: 'lv', displayName: 'Latvian'),
  LanguageOption(code: 'mg', displayName: 'Malagasy'),
  LanguageOption(code: 'mi', displayName: 'Maori'),
  LanguageOption(code: 'mk', displayName: 'Macedonian'),
  LanguageOption(code: 'ml', displayName: 'Malayalam'),
  LanguageOption(code: 'mn', displayName: 'Mongolian'),
  LanguageOption(code: 'mr', displayName: 'Marathi'),
  LanguageOption(code: 'ms', displayName: 'Malay'),
  LanguageOption(code: 'mt', displayName: 'Maltese'),
  LanguageOption(code: 'my', displayName: 'Myanmar'),
  LanguageOption(code: 'ne', displayName: 'Nepali'),
  LanguageOption(code: 'nn', displayName: 'Nynorsk'),
  LanguageOption(code: 'no', displayName: 'Norwegian'),
  LanguageOption(code: 'oc', displayName: 'Occitan'),
  LanguageOption(code: 'pa', displayName: 'Punjabi'),
  LanguageOption(code: 'pl', displayName: 'Polish'),
  LanguageOption(code: 'ps', displayName: 'Pashto'),
  LanguageOption(code: 'pt', displayName: 'Portuguese'),
  LanguageOption(code: 'ro', displayName: 'Romanian'),
  LanguageOption(code: 'ru', displayName: 'Russian'),
  LanguageOption(code: 'sa', displayName: 'Sanskrit'),
  LanguageOption(code: 'sd', displayName: 'Sindhi'),
  LanguageOption(code: 'si', displayName: 'Sinhala'),
  LanguageOption(code: 'sk', displayName: 'Slovak'),
  LanguageOption(code: 'sl', displayName: 'Slovenian'),
  LanguageOption(code: 'sn', displayName: 'Shona'),
  LanguageOption(code: 'so', displayName: 'Somali'),
  LanguageOption(code: 'sq', displayName: 'Albanian'),
  LanguageOption(code: 'sr', displayName: 'Serbian'),
  LanguageOption(code: 'su', displayName: 'Sundanese'),
  LanguageOption(code: 'sv', displayName: 'Swedish'),
  LanguageOption(code: 'sw', displayName: 'Swahili'),
  LanguageOption(code: 'ta', displayName: 'Tamil'),
  LanguageOption(code: 'te', displayName: 'Telugu'),
  LanguageOption(code: 'tg', displayName: 'Tajik'),
  LanguageOption(code: 'th', displayName: 'Thai'),
  LanguageOption(code: 'tk', displayName: 'Turkmen'),
  LanguageOption(code: 'tl', displayName: 'Tagalog'),
  LanguageOption(code: 'tr', displayName: 'Turkish'),
  LanguageOption(code: 'tt', displayName: 'Tatar'),
  LanguageOption(code: 'uk', displayName: 'Ukrainian'),
  LanguageOption(code: 'ur', displayName: 'Urdu'),
  LanguageOption(code: 'uz', displayName: 'Uzbek'),
  LanguageOption(code: 'vi', displayName: 'Vietnamese'),
  LanguageOption(code: 'yi', displayName: 'Yiddish'),
  LanguageOption(code: 'yo', displayName: 'Yoruba'),
  LanguageOption(code: 'yue', displayName: 'Cantonese'),
  LanguageOption(code: 'zh', displayName: 'Chinese'),
];

/// The set of codes Whisper recognizes (99 entries, excluding the
/// `auto` sentinel). Used by the service to validate a free-text
/// language pick.
const Set<String> _kWhisperLanguageCodes = {
  'en', 'zh', 'de', 'es', 'ru', 'ko', 'fr', 'ja', 'pt', 'tr', 'pl', 'ca',
  'nl', 'ar', 'sv', 'it', 'id', 'hi', 'fi', 'vi', 'he', 'uk', 'el', 'ms',
  'cs', 'ro', 'da', 'hu', 'ta', 'no', 'th', 'ur', 'hr', 'bg', 'lt', 'la',
  'mi', 'ml', 'cy', 'sk', 'te', 'fa', 'lv', 'bn', 'sr', 'az', 'sl', 'kn',
  'et', 'mk', 'br', 'eu', 'is', 'hy', 'ne', 'mn', 'bs', 'kk', 'sq', 'sw',
  'gl', 'mr', 'pa', 'si', 'km', 'sn', 'yo', 'so', 'af', 'oc', 'ka', 'be',
  'tg', 'sd', 'gu', 'am', 'yi', 'lo', 'uz', 'fo', 'ht', 'ps', 'tk', 'nn',
  'mt', 'sa', 'lb', 'my', 'bo', 'tl', 'mg', 'as', 'tt', 'haw', 'ln', 'ha',
  'ba', 'jw', 'su', 'yue',
};

/// Returns `true` if [code] is either the `"auto"` sentinel or one
/// of the 99 language codes Whisper accepts.
bool isWhisperLanguageCode(String code) =>
    code == 'auto' || _kWhisperLanguageCodes.contains(code);
