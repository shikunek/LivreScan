import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livrescan/app/app.dart';
import 'package:livrescan/core/settings/language_settings.dart';
import 'package:livrescan/features/flashcards/domain/entities/deck.dart';
import 'package:livrescan/features/flashcards/presentation/providers/decks_provider.dart';

Future<Widget> _app() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      decksProvider.overrideWith((ref) async => const <Deck>[]),
    ],
    child: const LivreScanApp(),
  );
}

void main() {
  testWidgets('app boots and shows the deck list screen', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.text('LivreScan'), findsOneWidget);
    expect(find.text('Skenovat stránku'), findsOneWidget);
  });

  testWidgets('language picker defaults to fr → cs and can be changed', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.text('Francouzština'), findsOneWidget);
    expect(find.text('Čeština'), findsOneWidget);

    await tester.tap(find.text('Čeština'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Angličtina'));
    await tester.pumpAndSettle();

    expect(find.text('Angličtina'), findsOneWidget);
    expect(find.text('Čeština'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('targetLang'), 'en');
  });

  testWidgets('swap flips the pair', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sourceLang'), 'cs');
    expect(prefs.getString('targetLang'), 'fr');
  });
}
