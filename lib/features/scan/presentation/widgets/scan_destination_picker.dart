import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../flashcards/domain/entities/deck.dart';
import '../../domain/entities/scan_destination.dart';

/// A name for a new deck that isn't taken yet: "Sken 21. 9.", then
/// "Sken 21. 9. (2)", "Sken 21. 9. (3)", ...
String suggestDeckName(Iterable<String> existingNames, DateTime now) {
  final base = 'Sken ${now.day}. ${now.month}.';
  final taken = existingNames.toSet();
  if (!taken.contains(base)) return base;
  for (var n = 2;; n++) {
    final candidate = '$base ($n)';
    if (!taken.contains(candidate)) return candidate;
  }
}

/// Asks where the scanned words should go. [decksForPair] are the existing
/// decks of the current language pair. With none there is nothing to choose
/// from, so it returns [DefaultDeck] without asking. Returns null if the user
/// backs out.
Future<ScanDestination?> chooseScanDestination(
  BuildContext context, {
  required List<Deck> decksForPair,
  required DateTime now,
}) async {
  if (decksForPair.isEmpty) return const DefaultDeck();

  final choice = await showCupertinoModalPopup<Object>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: const Text('Kam uložit slovíčka?'),
      actions: [
        CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(_newDeckChoice),
          child: const Text('Nový deck'),
        ),
        // Newest first: the deck used last is the most likely target.
        for (final deck in decksForPair.reversed)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(deck),
            child: Text(deck.name),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Zrušit'),
      ),
    ),
  );

  if (choice is Deck) return ExistingDeck(choice.id);
  if (choice != _newDeckChoice || !context.mounted) return null;

  final suggested = suggestDeckName(decksForPair.map((d) => d.name), now);
  final name = await _askDeckName(context, suggested);
  return name == null ? null : NewDeck(name);
}

const _newDeckChoice = Object();

Future<String?> _askDeckName(BuildContext context, String suggested) async {
  final controller = TextEditingController(text: suggested)
    ..selection = TextSelection(baseOffset: 0, extentOffset: suggested.length);

  final name = await showCupertinoDialog<String>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('Nový deck'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: controller,
          autofocus: true,
          placeholder: 'Název decku',
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zrušit'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop(controller.text);
          },
          child: const Text('Vytvořit'),
        ),
      ],
    ),
  );
  controller.dispose();

  if (name == null) return null;
  final trimmed = name.trim();
  return trimmed.isEmpty ? suggested : trimmed;
}
