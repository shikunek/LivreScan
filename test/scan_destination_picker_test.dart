import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:livrescan/features/flashcards/domain/entities/deck.dart';
import 'package:livrescan/features/scan/domain/entities/scan_destination.dart';
import 'package:livrescan/features/scan/presentation/widgets/scan_destination_picker.dart';

const _decks = [
  Deck(id: 1, name: 'Kapitola 1', sourceLang: 'fr', targetLang: 'cs'),
  Deck(id: 2, name: 'Kapitola 2', sourceLang: 'fr', targetLang: 'cs'),
];

final _now = DateTime(2026, 9, 21, 10, 33);

/// Pumps a button that runs the picker and keeps its result.
Future<ValueNotifier<Object?>> _pump(WidgetTester tester, List<Deck> decks) async {
  final result = ValueNotifier<Object?>('not asked yet');
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result.value = await chooseScanDestination(context, decksForPair: decks, now: _now);
          },
          child: const Text('Hotovo'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Hotovo'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('suggestDeckName', () {
    test('uses the date', () {
      expect(suggestDeckName(const [], _now), 'Sken 21. 9.');
    });

    test('numbers a name that is already taken', () {
      expect(suggestDeckName(const ['Sken 21. 9.'], _now), 'Sken 21. 9. (2)');
      expect(suggestDeckName(const ['Sken 21. 9.', 'Sken 21. 9. (2)'], _now), 'Sken 21. 9. (3)');
    });
  });

  group('chooseScanDestination', () {
    testWidgets('with no deck for the language pair it does not ask', (tester) async {
      final result = await _pump(tester, const []);

      expect(find.text('Kam uložit slovíčka?'), findsNothing);
      expect(result.value, isA<DefaultDeck>());
    });

    testWidgets('offers a new deck and the existing ones, newest first', (tester) async {
      await _pump(tester, _decks);

      expect(find.text('Kam uložit slovíčka?'), findsOneWidget);
      expect(find.text('Nový deck'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Kapitola 2')).dy,
        lessThan(tester.getTopLeft(find.text('Kapitola 1')).dy),
      );
    });

    testWidgets('choosing an existing deck returns it', (tester) async {
      final result = await _pump(tester, _decks);

      await tester.tap(find.text('Kapitola 1'));
      await tester.pumpAndSettle();

      expect(result.value, isA<ExistingDeck>());
      expect((result.value! as ExistingDeck).deckId, 1);
    });

    testWidgets('a new deck asks for a name, prefilled and ready to use', (tester) async {
      final result = await _pump(tester, _decks);

      await tester.tap(find.text('Nový deck'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(CupertinoTextField, 'Sken 21. 9.'), findsOneWidget);

      await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Vytvořit'));
      await tester.pumpAndSettle();

      expect((result.value! as NewDeck).name, 'Sken 21. 9.');
    });

    testWidgets('the name can be changed, and a blank name falls back to the suggestion',
        (tester) async {
      final result = await _pump(tester, _decks);
      await tester.tap(find.text('Nový deck'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(CupertinoTextField), '  Kapitola 3  ');
      await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Vytvořit'));
      await tester.pumpAndSettle();
      expect((result.value! as NewDeck).name, 'Kapitola 3');

      await tester.tap(find.text('Hotovo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nový deck'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), '   ');
      await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Vytvořit'));
      await tester.pumpAndSettle();
      expect((result.value! as NewDeck).name, 'Sken 21. 9.');
    });

    testWidgets('cancelling the sheet or the name dialog returns null', (tester) async {
      final result = await _pump(tester, _decks);
      await tester.tap(find.text('Zrušit'));
      await tester.pumpAndSettle();
      expect(result.value, isNull);

      await tester.tap(find.text('Hotovo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nový deck'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Zrušit'));
      await tester.pumpAndSettle();
      expect(result.value, isNull);
    });
  });
}
