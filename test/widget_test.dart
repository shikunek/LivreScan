import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:livrescan/app/app.dart';
import 'package:livrescan/features/flashcards/domain/entities/deck.dart';
import 'package:livrescan/features/flashcards/presentation/providers/decks_provider.dart';

void main() {
  testWidgets('app boots and shows the deck list screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decksProvider.overrideWith((ref) async => const <Deck>[]),
        ],
        child: const LivreScanApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LivreScan'), findsOneWidget);
    expect(find.text('Skenovat stránku'), findsOneWidget);
  });
}
