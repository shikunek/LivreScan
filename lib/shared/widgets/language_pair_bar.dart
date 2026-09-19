import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/languages.dart';
import '../../core/settings/language_settings.dart';

/// Shows the current source → target language pair and lets the user change
/// either side or flip them. Used as the "what am I scanning" control.
class LanguagePairBar extends ConsumerWidget {
  const LanguagePairBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(languageSettingsProvider);
    final notifier = ref.read(languageSettingsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _LanguageChip(
              label: 'Skenuji z',
              language: languageByCode(pair.source),
              onTap: () async {
                final code = await _pickLanguage(
                  context,
                  title: 'Jazyk knihy',
                  selected: pair.source,
                  languages: kLanguages
                      .where((l) => l.canScan && l.code != pair.target)
                      .toList(),
                );
                if (code != null) notifier.setSource(code);
              },
            ),
          ),
          IconButton(
            tooltip: 'Prohodit jazyky',
            onPressed: notifier.canSwap ? notifier.swap : null,
            icon: const Icon(Icons.swap_horiz),
          ),
          Expanded(
            child: _LanguageChip(
              label: 'Překládám do',
              language: languageByCode(pair.target),
              onTap: () async {
                final code = await _pickLanguage(
                  context,
                  title: 'Jazyk překladu',
                  selected: pair.target,
                  languages: kLanguages.where((l) => l.code != pair.source).toList(),
                );
                if (code != null) notifier.setTarget(code);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.label, required this.language, required this.onTap});

  final String label;
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelSmall),
                    Text(
                      language.name,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _pickLanguage(
  BuildContext context, {
  required String title,
  required String selected,
  required List<AppLanguage> languages,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final language in languages)
                      ListTile(
                        title: Text(language.name),
                        trailing: language.code == selected ? const Icon(Icons.check) : null,
                        onTap: () => Navigator.of(context).pop(language.code),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
