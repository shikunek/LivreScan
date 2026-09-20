import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Row(
        children: [
          Flexible(
            child: _LanguagePill(
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
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(36, 36),
            onPressed: notifier.canSwap
                ? () {
                    HapticFeedback.selectionClick();
                    notifier.swap();
                  }
                : null,
            child: const Icon(
              CupertinoIcons.arrow_right_arrow_left,
              size: 16,
              color: AppColors.inkSecondary,
              semanticLabel: 'Prohodit jazyky',
            ),
          ),
          Flexible(
            child: _LanguagePill(
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

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.language, required this.onTap});

  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outline, width: 0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                language.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(CupertinoIcons.chevron_down, size: 12, color: AppColors.inkSecondary),
          ],
        ),
      ),
    );
  }
}

/// iOS action sheet; the currently selected language is shown in bold.
Future<String?> _pickLanguage(
  BuildContext context, {
  required String title,
  required String selected,
  required List<AppLanguage> languages,
}) {
  return showCupertinoModalPopup<String>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: Text(title),
      actions: [
        for (final language in languages)
          CupertinoActionSheetAction(
            isDefaultAction: language.code == selected,
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop(language.code);
            },
            child: Text(language.name),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Zrušit'),
      ),
    ),
  );
}
