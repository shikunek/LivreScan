import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livrescan/core/di/providers.dart';
import 'package:livrescan/core/settings/language_settings.dart';
import 'package:livrescan/core/srs/sm2_scheduler.dart';
import 'package:livrescan/core/storage/database.dart';
import 'package:livrescan/features/flashcards/data/repositories/flashcard_repository_impl.dart';
import 'package:livrescan/features/flashcards/domain/entities/deck.dart';
import 'package:livrescan/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:livrescan/features/flashcards/presentation/screens/deck_list_screen.dart';
import 'package:livrescan/features/scan/domain/entities/vocab_candidate.dart';

class _FakeRepository extends Fake implements FlashcardRepository {
  _FakeRepository({this.failDelete = false});

  final bool failDelete;
  final decks = [
    const Deck(id: 1, name: 'Moje slovíčka', sourceLang: 'fr', targetLang: 'cs'),
    const Deck(id: 2, name: 'Moje slovíčka', sourceLang: 'en', targetLang: 'cs'),
  ];
  final deleted = <int>[];

  @override
  Future<List<Deck>> getDecks() async => List.of(decks);

  @override
  Future<void> deleteDeck(int deckId) async {
    if (failDelete) throw Exception('disk full');
    deleted.add(deckId);
    decks.removeWhere((d) => d.id == deckId);
  }
}

Future<void> _pumpDeckList(WidgetTester tester, _FakeRepository repository) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        flashcardRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: DeckListScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Swipes the first deck tile right-to-left.
Future<void> _swipeFirstDeck(WidgetTester tester) async {
  await tester.drag(find.text('Francouzština → Čeština'), const Offset(-500, 0));
  await tester.pumpAndSettle();
}

void main() {
  group('swipe to reveal "Smazat", tap it to delete a deck', () {
    testWidgets('swipe only slides out "Smazat"; tapping it deletes the deck', (tester) async {
      final repository = _FakeRepository();
      await _pumpDeckList(tester, repository);
      expect(find.text('Smazat'), findsNothing);

      await _swipeFirstDeck(tester);
      expect(find.text('Smazat'), findsOneWidget);
      expect(repository.deleted, isEmpty);
      expect(find.text('Francouzština → Čeština'), findsOneWidget);

      await tester.tap(find.text('Smazat'));
      await tester.pumpAndSettle();

      expect(repository.deleted, [1]);
      expect(find.text('Francouzština → Čeština'), findsNothing);
      expect(find.text('Angličtina → Čeština'), findsOneWidget);
    });

    testWidgets('swiping another row closes the open one and opens that one instead', (tester) async {
      final repository = _FakeRepository();
      await _pumpDeckList(tester, repository);
      final first = find.text('Francouzština → Čeština');
      final second = find.text('Angličtina → Čeština');
      final restingX = tester.getTopLeft(first).dx;

      await _swipeFirstDeck(tester);
      expect(tester.getTopLeft(first).dx, lessThan(restingX)); // first is open

      // While a row is open the other rows sit behind the package's barrier,
      // so the test framework reports the drag as "missed" - it still works.
      await tester.drag(second, const Offset(-500, 0), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(first).dx, restingX); // first closed
      expect(tester.getTopLeft(second).dx, lessThan(restingX)); // second open
      expect(find.text('Smazat'), findsOneWidget); // only one action pane at a time
      expect(repository.deleted, isEmpty);
    });

    testWidgets('left-to-right swipe does not reveal anything', (tester) async {
      final repository = _FakeRepository();
      await _pumpDeckList(tester, repository);

      await tester.drag(find.text('Francouzština → Čeština'), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Smazat'), findsNothing);
      expect(find.text('Francouzština → Čeština'), findsOneWidget);
    });

    testWidgets('a failed deletion brings the deck back and says so', (tester) async {
      final repository = _FakeRepository(failDelete: true);
      await _pumpDeckList(tester, repository);

      await _swipeFirstDeck(tester);
      await tester.tap(find.text('Smazat'));
      await tester.pumpAndSettle();

      expect(find.text('Deck se nepodařilo smazat.'), findsOneWidget);
      expect(find.text('Francouzština → Čeština'), findsOneWidget);
    });
  });

  test('FlashcardRepositoryImpl.deleteDeck removes the deck and only its cards', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = FlashcardRepositoryImpl(db, Sm2Scheduler());

    const candidate = VocabCandidate(
      original: 'kniha',
      translation: 'book',
      type: VocabType.word,
      exampleSentence: '',
    );
    final fr = await repository.createDeck(name: 'A', sourceLang: 'fr', targetLang: 'cs');
    final en = await repository.createDeck(name: 'B', sourceLang: 'en', targetLang: 'cs');
    await repository.saveCandidates(deckId: fr.id, candidates: [candidate, candidate]);
    await repository.saveCandidates(deckId: en.id, candidates: [candidate]);

    await repository.deleteDeck(fr.id);

    expect((await repository.getDecks()).map((d) => d.id), [en.id]);
    final cards = await db.select(db.cards).get();
    expect(cards.map((c) => c.deckId), [en.id]);
  });
}
