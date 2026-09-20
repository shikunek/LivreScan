import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livrescan/app/router.dart';
import 'package:livrescan/core/di/providers.dart';
import 'package:livrescan/core/settings/language_settings.dart';
import 'package:livrescan/core/srs/sm2_scheduler.dart';
import 'package:livrescan/core/storage/database.dart';
import 'package:livrescan/features/flashcards/data/repositories/flashcard_repository_impl.dart';
import 'package:livrescan/features/flashcards/domain/entities/deck.dart';
import 'package:livrescan/features/flashcards/domain/entities/flashcard.dart';
import 'package:livrescan/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:livrescan/features/flashcards/presentation/screens/deck_list_screen.dart';
import 'package:livrescan/features/flashcards/presentation/screens/word_list_screen.dart';
import 'package:livrescan/features/scan/domain/entities/vocab_candidate.dart';

Flashcard _card(int id, String original, String translation) => Flashcard(
      id: id,
      deckId: 1,
      original: original,
      translation: translation,
      type: VocabType.word,
      exampleSentence: 'Věta, která se v seznamu nezobrazuje.',
      srs: Sm2State.initial(),
    );

class _FakeRepository extends Fake implements FlashcardRepository {
  _FakeRepository(this.cards);

  final List<Flashcard> cards;

  @override
  Future<List<Deck>> getDecks() async => const [
        Deck(id: 1, name: 'Moje slovíčka', sourceLang: 'fr', targetLang: 'cs'),
      ];

  @override
  Future<List<Flashcard>> getCards(int deckId) async => cards;
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  testWidgets('word list shows every word with its translation, and the count', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          flashcardRepositoryProvider.overrideWithValue(
            _FakeRepository([_card(2, 'livre', 'kniha'), _card(1, 'courir', 'běžet')]),
          ),
        ],
        child: const MaterialApp(home: WordListScreen(deckId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Slovíčka'), findsOneWidget);
    expect(find.text('Francouzština → Čeština · 2 slovíčka'), findsOneWidget);
    expect(find.text('livre'), findsOneWidget);
    expect(find.text('kniha'), findsOneWidget);
    expect(find.text('courir'), findsOneWidget);
    expect(find.text('běžet'), findsOneWidget);
    // Order is kept as the repository returns it (newest first).
    expect(
      tester.getTopLeft(find.text('livre')).dy,
      lessThan(tester.getTopLeft(find.text('courir')).dy),
    );
    expect(find.text('Věta, která se v seznamu nezobrazuje.'), findsNothing);
  });

  testWidgets('word list of an empty deck says so', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [flashcardRepositoryProvider.overrideWithValue(_FakeRepository(const []))],
        child: const MaterialApp(home: WordListScreen(deckId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('V tomhle decku zatím nejsou žádná slovíčka.'), findsOneWidget);
    expect(find.text('Francouzština → Čeština · 0 slovíček'), findsOneWidget);
  });

  testWidgets('the list button on a deck row opens that deck\'s words', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const DeckListScreen()),
        GoRoute(
          path: '/deck/:deckId/words',
          builder: (_, state) =>
              WordListScreen(deckId: int.parse(state.pathParameters['deckId']!)),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await _prefs()),
          flashcardRepositoryProvider.overrideWithValue(
            _FakeRepository([_card(1, 'courir', 'běžet')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.list_bullet));
    await tester.pumpAndSettle();

    expect(find.text('Slovíčka'), findsOneWidget);
    expect(find.text('courir'), findsOneWidget);
    expect(find.text('běžet'), findsOneWidget);
  });

  test('the app router has the word list route', () {
    final paths = appRouter.configuration.routes.whereType<GoRoute>().map((r) => r.path);
    expect(paths, contains('/deck/:deckId/words'));
  });

  test('FlashcardRepositoryImpl.getCards returns only that deck, newest first', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = FlashcardRepositoryImpl(db, Sm2Scheduler());

    VocabCandidate word(String original) => VocabCandidate(
          original: original,
          translation: 'x',
          type: VocabType.word,
          exampleSentence: '',
        );
    final fr = await repository.createDeck(name: 'A', sourceLang: 'fr', targetLang: 'cs');
    final en = await repository.createDeck(name: 'B', sourceLang: 'en', targetLang: 'cs');
    await repository.saveCandidates(deckId: fr.id, candidates: [word('un'), word('deux')]);
    await repository.saveCandidates(deckId: en.id, candidates: [word('one')]);
    await repository.saveCandidates(deckId: fr.id, candidates: [word('trois')]);

    final cards = await repository.getCards(fr.id);

    expect(cards.map((c) => c.original), ['trois', 'deux', 'un']);
  });
}
