import 'package:flutter/material.dart';

import '../../../services/supported_languages.dart';

/// Searchable language picker.
///
/// With 100 entries a plain [DropdownButton] is too painful to
/// scroll, so the picker is rendered as an `InputDecoration`-styled
/// button that opens a bottom sheet with a search field and a
/// scrollable list. Filtering is case-insensitive and matches the
/// display name OR the language code.
class LanguageDropdown extends StatelessWidget {
  const LanguageDropdown({
    super.key,
    required this.languages,
    required this.selectedCode,
    required this.enabled,
    required this.onChanged,
  });

  final List<LanguageOption> languages;
  final String selectedCode;
  final bool enabled;
  final ValueChanged<String> onChanged;

  String? _displayNameFor(String code) {
    for (final l in languages) {
      if (l.code == code) return l.displayName;
    }
    return null;
  }

  Future<void> _openSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _LanguagePickerSheet(
        languages: languages,
        selectedCode: selectedCode,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = _displayNameFor(selectedCode) ?? selectedCode;

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
                  InkWell(
                    onTap: enabled ? () => _openSheet(context) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: theme.textTheme.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
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

/// Bottom sheet with a search box and a virtualized list of all
/// supported languages. Tapping a row returns its code via
/// [showModalBottomSheet].
class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({
    required this.languages,
    required this.selectedCode,
  });

  final List<LanguageOption> languages;
  final String selectedCode;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<LanguageOption> get _filtered {
    if (_query.isEmpty) return widget.languages;
    final q = _query.toLowerCase();
    return [
      for (final l in widget.languages)
        if (l.displayName.toLowerCase().contains(q) ||
            l.code.toLowerCase().contains(q))
          l,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;

    // Cap the sheet height to ~80% of the screen so it doesn't
    // cover the whole UI on a small device.
    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return SizedBox(
      height: maxHeight,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search language or code…',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} of ${widget.languages.length}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matches for "$_query"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.disabledColor,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final l = filtered[i];
                      final isSelected = l.code == widget.selectedCode;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        leading: isSelected
                            ? const Icon(Icons.check, size: 20)
                            : const SizedBox(width: 20),
                        title: Text(l.displayName),
                        subtitle: Text(
                          l.code,
                          style: theme.textTheme.bodySmall,
                        ),
                        onTap: () => Navigator.of(context).pop(l.code),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
