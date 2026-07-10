import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' show LocaleName;

import '../../../services/supported_languages.dart';

class LocaleDropdown extends StatelessWidget {
  const LocaleDropdown({
    super.key,
    required this.languages,
    required this.selectedCode,
    required this.enabled,
    required this.onChanged,
    this.selectedDeviceLocaleId,
    this.onDeviceLocaleChanged,
    this.deviceLocales = const [],
  });

  /// The curated list of languages, with availability information.
  final List<LanguageEntry> languages;

  /// Stable id of the currently selected curated language
  /// (matches [LanguageConfig.code], e.g. `"en-GB"`, `"ta"`).
  final String? selectedCode;

  /// Raw device locale id of the currently selected "Default locales"
  /// entry (e.g. `"zh-HK"`). Mutually exclusive with [selectedCode] in
  /// practice — only one is non-null at a time.
  final String? selectedDeviceLocaleId;

  /// Whether the dropdown is interactive. Typically false while
  /// recognition is in progress.
  final bool enabled;

  /// Called with the picked curated language's [LanguageConfig.code].
  final ValueChanged<String> onChanged;

  /// Called with the picked "Default locales" entry's raw device
  /// locale id (e.g. `"zh-HK"`).
  final ValueChanged<String>? onDeviceLocaleChanged;

  /// Locales the device's recognizer reports in `speech.locales()` that
  /// do NOT match any curated entry. Shown at the bottom of the
  /// dropdown as a selectable "Default locales" section.
  final List<LocaleName> deviceLocales;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Bucket the curated list into the three groups that drive the
    // dropdown's sections. The available group has no header; the
    // other two each get one.
    final availableCurated = <LanguageEntry>[
      for (final e in languages)
        if (e.isAvailable) e,
    ];
    final notInstalledCurated = <LanguageEntry>[
      for (final e in languages)
        if (!e.isAvailable && !e.isCloudOnly) e,
    ];
    final cloudOnlyCurated = <LanguageEntry>[
      for (final e in languages)
        if (e.isCloudOnly) e,
    ];

    // Hint: only show "nothing available" when nothing is selectable at
    // all. With the new sections, not-installed and cloud-only entries
    // are still selectable, so we only suppress the dropdown contents
    // when there's truly nothing the user can pick.
    final hasAnything = availableCurated.isNotEmpty ||
        notInstalledCurated.isNotEmpty ||
        cloudOnlyCurated.isNotEmpty ||
        deviceLocales.isNotEmpty;
    final hint = hasAnything
        ? 'Select a language'
        : 'No languages available on this device';

    // Compute items first, then derive `value` from the items themselves.
    // `DropdownButton` requires exactly one item with a given value, so
    // the *effective* value we hand to the widget has to match an actual
    // item's value. All curated entries are now selectable regardless of
    // availability (the user explicitly asked for that), so every
    // curated item gets a non-null `value` (its `LanguageConfig.code`).
    //
    // The list is split into:
    //   1. Available curated entries (no header — primary list)
    //   2. Not-installed curated entries (with a "Not installed" header)
    //   3. Cloud-only curated entries (with a "Cloud only" header)
    //   4. Default locales (raw device locales that aren't curated)
    // Sections 2-4 are separated from the primary list and from each
    // other by a thin divider + header.
    final items = <DropdownMenuItem<String>>[
      for (final entry in availableCurated)
        DropdownMenuItem<String>(
          value: entry.config.code,
          enabled: true,
          child: _LanguageRow(entry: entry),
        ),
      if (notInstalledCurated.isNotEmpty) ...[
        const DropdownMenuItem<String>(
          value: null,
          enabled: false,
          child: _SectionDivider(),
        ),
        const DropdownMenuItem<String>(
          value: null,
          enabled: false,
          child: _SectionHeader(
            title: 'Not installed',
            icon: Icons.warning_amber_rounded,
          ),
        ),
        for (final entry in notInstalledCurated)
          DropdownMenuItem<String>(
            value: entry.config.code,
            enabled: true,
            child: _LanguageRow(entry: entry),
          ),
      ],
      if (cloudOnlyCurated.isNotEmpty) ...[
        const DropdownMenuItem<String>(
          value: null,
          enabled: false,
          child: _SectionDivider(),
        ),
        const DropdownMenuItem<String>(
          value: null,
          enabled: false,
          child: _SectionHeader(
            title: 'Cloud only',
            icon: Icons.cloud_outlined,
          ),
        ),
        for (final entry in cloudOnlyCurated)
          DropdownMenuItem<String>(
            value: entry.config.code,
            enabled: true,
            child: _LanguageRow(entry: entry),
          ),
      ],
      if (deviceLocales.isNotEmpty) ...[
        const DropdownMenuItem<String>(
          value: null,
          enabled: false,
          child: _SectionDivider(),
        ),
        const DropdownMenuItem<String>(
          value: null,
          enabled: false,
          child: _SectionHeader(
            title: 'Default locales',
            icon: Icons.smartphone,
          ),
        ),
        for (final l in deviceLocales)
          DropdownMenuItem<String>(
            value: l.localeId,
            enabled: true,
            child: _DeviceLocaleRow(locale: l),
          ),
      ],
    ];

    // `effectiveValue` must be a value that appears exactly once in the
    // items. We only count non-null values; multiple `null` values are
    // legal because the dropdown treats them as "no selection".
    //
    // The selection can be either a curated code (e.g. `en-GB`) or a
    // raw device locale id (e.g. `zh-HK`); both appear in `items` as
    // non-null values. We pick whichever one the service currently
    // holds.
    final availableValues = {
      for (final item in items)
        if (item.value != null) item.value as String,
    };
    final String? curatedValue = (selectedCode != null &&
            availableValues.contains(selectedCode))
        ? selectedCode
        : null;
    final String? deviceValue =
        (selectedDeviceLocaleId != null &&
                availableValues.contains(selectedDeviceLocaleId))
            ? selectedDeviceLocaleId
            : null;
    final String? effectiveValue = curatedValue ?? deviceValue;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.language),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recognition language',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: effectiveValue,
                      hint: Text(hint),
                      items: items,
                      onChanged: !enabled
                          ? null
                          : (value) {
                              if (value == null) return;
                              // Distinguish curated picks (which look
                              // like a `LanguageConfig.code`) from
                              // device-only picks (which look like a
                              // raw device locale id like `zh-HK`).
                              if (onDeviceLocaleChanged != null &&
                                  deviceLocales.any(
                                    (l) => l.localeId == value,
                                  )) {
                                onDeviceLocaleChanged!(value);
                              } else {
                                onChanged(value);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.entry});

  final LanguageEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintColor = theme.hintColor;
    final disabledColor = theme.disabledColor;

    // Show the BCP-47 tag in the row (what actually gets sent to the
    // recognizer) so it's easy to verify the config at a glance.
    final codeLabel = entry.config.bcp47;

    return Row(
      children: [
        Expanded(
          child: Text(
            _displayName(entry.config),
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          codeLabel,
          style: theme.textTheme.bodySmall?.copyWith(color: hintColor),
        ),
        if (entry.isCloudOnly) ...[
          const SizedBox(width: 6),
          Tooltip(
            message:
                'Cloud-only language — recognition will go through the network and is not available offline.',
            child: Icon(Icons.cloud_outlined, size: 16, color: disabledColor),
          ),
        ] else if (!entry.isAvailable) ...[
          const SizedBox(width: 6),
          Tooltip(
            message:
                'Not installed on this device. Recognition may use a similar installed language or fall back to the network.',
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: disabledColor,
            ),
          ),
        ],
      ],
    );
  }

  String _displayName(LanguageConfig cfg) {
    const names = <String, String>{
      'bg': 'Bulgarian',
      'cs': 'Czech',
      'da': 'Danish',
      'de': 'German',
      'el': 'Greek',
      'es': 'Spanish',
      'fi': 'Finnish',
      'fr': 'French',
      'hu': 'Hungarian',
      'id-ID': 'Indonesian',
      'it': 'Italian',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ms': 'Malay',
      'nb-NO': 'Norwegian Bokmål',
      'nl': 'Dutch',
      'pl': 'Polish',
      'pt-BR': 'Portuguese (Brazil)',
      'ro': 'Romanian',
      'ru': 'Russian',
      'sv': 'Swedish',
      'th': 'Thai',
      'tr': 'Turkish',
      'uk': 'Ukrainian',
      'vi': 'Vietnamese',
      'zh': 'Chinese (Simplified)',
      'zh-Hant': 'Chinese (Traditional)',
      'hi': 'Hindi',
      'pt': 'Portuguese (Portugal)',
      'en-GB': 'English (UK)',
      'sr-Cyrl': 'Serbian (Cyrillic)',
      'lv-LV': 'Latvian',
      'hr': 'Croatian',
      'sl': 'Slovenian',
      'ta': 'Tamil',
      'si': 'Sinhala',
      'lt-LT': 'Lithuanian',
      'cy-GB': 'Welsh',
      'et-EE': 'Estonian',
      'fil-PH': 'Filipino',
    };
    return names[cfg.code] ?? cfg.code;
  }
}

/// Thin visual separator rendered between sections in the dropdown.
class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).dividerColor,
      ),
    );
  }
}

/// Header for a section in the dropdown. Non-selectable; the section's
/// icon hints at the status of the entries below (e.g. a cloud icon
/// for the "Cloud only" section).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.disabledColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.disabledColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One selectable row in the "Default locales" section. Shows the
/// locale's display name (e.g. "Chinese (Hong Kong)") and its raw id
/// (e.g. `zh-HK`). The id is what gets handed to the recognizer when
/// the user picks this row.
class _DeviceLocaleRow extends StatelessWidget {
  const _DeviceLocaleRow({required this.locale});

  final LocaleName locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintColor = theme.hintColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              locale.name.isEmpty ? locale.localeId : locale.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            locale.localeId,
            style: theme.textTheme.bodySmall?.copyWith(color: hintColor),
          ),
        ],
      ),
    );
  }
}
