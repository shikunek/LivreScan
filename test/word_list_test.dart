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

class _RecordingRepository extends _FakeRepository {
  _RecordingRepository(super.cards);

  final markedDueNow = <int>[];

  @override
  Future<void> markDueNow(int cardId) async => markedDueNow.add(cardId);
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

  group('card detail sheet', () {
    Flashcard cardWithSrs(Sm2State srs, {String? partOfSpeech}) => Flashcard(
          id: 1,
          deckId: 1,
          original: 'courir',
          translation: 'běžet',
          type: VocabType.word,
          exampleSentence: 'Il aime courir le matin.',
          partOfSpeech: partOfSpeech,
          srs: srs,
        );

    Future<void> pumpAndOpen(WidgetTester tester, Flashcard card) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [flashcardRepositoryProvider.overrideWithValue(_FakeRepository([card]))],
          child: const MaterialApp(home: WordListScreen(deckId: 1)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('courir'));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a row shows word details including SM-2 state not shown in the list',
        (tester) async {
      await pumpAndOpen(
        tester,
        cardWithSrs(
          Sm2State(
            easeFactor: 2.5,
            intervalDays: 0,
            repetitions: 0,
            dueDate: DateTime.now(),
          ),
        ),
      );

      expect(find.text('slovo'), findsOneWidget);
      expect(find.text('—'), findsOneWidget); // no part of speech given
      expect(find.text('Il aime courir le matin.'), findsOneWidget);
      expect(find.text('2.50'), findsOneWidget);
      expect(find.text('zatím neopakováno'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // repetitions
    });

    testWidgets('a phrase and a known part of speech are shown as such', (tester) async {
      await pumpAndOpen(
        tester,
        Flashcard(
          id: 1,
          deckId: 1,
          original: 'courir',
          translation: 'běžet',
          type: VocabType.phrase,
          exampleSentence: 'Il aime courir le matin.',
          partOfSpeech: 'verb',
          srs: Sm2State.initial(),
        ),
      );

      expect(find.text('fráze'), findsOneWidget);
      expect(find.text('verb'), findsOneWidget);
    });

    // Each case is its own test (not a loop of pumpWidget calls within one
    // test): a second pumpWidget while a modal sheet from the first is still
    // settling leaves stray matches behind and makes find.text ambiguous.
    for (final (days, expected) in [(1, '1 den'), (3, '3 dny'), (5, '5 dní')]) {
      testWidgets('interval of $days day(s) is shown as "$expected"', (tester) async {
        await pumpAndOpen(
          tester,
          cardWithSrs(
            Sm2State(
              easeFactor: 2.5,
              intervalDays: days,
              repetitions: 1,
              dueDate: DateTime.now().add(Duration(days: days)),
            ),
          ),
        );
        expect(find.text(expected), findsOneWidget);
      });
    }

    for (final (label, offset, expectedSubstring) in [
      ('already due', Duration.zero, 'už teď'),
      ('tomorrow', const Duration(days: 1), 'zítra'),
      ('in 6 days', const Duration(days: 6), 'za 6 dní'),
    ]) {
      testWidgets('the due date $label is described as "$expectedSubstring"', (tester) async {
        await pumpAndOpen(
          tester,
          cardWithSrs(
            Sm2State(
              easeFactor: 2.5,
              intervalDays: 1,
              repetitions: 1,
              dueDate: DateTime.now().add(offset),
            ),
          ),
        );
        expect(find.textContaining(expectedSubstring), findsOneWidget);
      });
    }
  });

  group('marking a card due now', () {
    Flashcard futureCard() => Flashcard(
          id: 1,
          deckId: 1,
          original: 'courir',
          translation: 'běžet',
          type: VocabType.word,
          exampleSentence: '',
          srs: Sm2State(
            easeFactor: 2.5,
            intervalDays: 6,
            repetitions: 2,
            dueDate: DateTime.now().add(const Duration(days: 6)),
          ),
        );

    testWidgets('shows a button only for a card that is not due yet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            flashcardRepositoryProvider.overrideWithValue(_FakeRepository([futureCard()])),
          ],
          child: const MaterialApp(home: WordListScreen(deckId: 1)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('courir'));
      await tester.pumpAndSettle();

      expect(find.text('Procvičit hned'), findsOneWidget);
    });

    testWidgets('is absent for a card that is already due', (tester) async {
      final due = Flashcard(
        id: 1,
        deckId: 1,
        original: 'courir',
        translation: 'běžet',
        type: VocabType.word,
        exampleSentence: '',
        srs: Sm2State.initial(), // dueDate = now
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [flashcardRepositoryProvider.overrideWithValue(_FakeRepository([due]))],
          child: const MaterialApp(home: WordListScreen(deckId: 1)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('courir'));
      await tester.pumpAndSettle();

      expect(find.text('Procvičit hned'), findsNothing);
    });

    testWidgets('tapping it marks the card due now and closes the sheet', (tester) async {
      final repository = _RecordingRepository([futureCard()]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [flashcardRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: WordListScreen(deckId: 1)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('courir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Procvičit hned'));
      await tester.pumpAndSettle();

      expect(repository.markedDueNow, [1]);
      expect(find.text('Procvičit hned'), findsNothing); // sheet closed
    });

    test('FlashcardRepositoryImpl.markDueNow sets dueDate without touching SM-2 stats',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = FlashcardRepositoryImpl(db, Sm2Scheduler());
      final deck = await repository.createDeck(name: 'A', sourceLang: 'fr', targetLang: 'cs');
      final saved = await repository.saveCandidates(
        deckId: deck.id,
        candidates: const [
          VocabCandidate(original: 'a', translation: 'x', type: VocabType.word, exampleSentence: ''),
        ],
      );
      await repository.submitReview(saved.first.id, ReviewGrade.hard);
      final beforeCard = (await repository.getCards(deck.id)).single;

      await repository.markDueNow(saved.first.id);

      final afterCard = (await repository.getCards(deck.id)).single;
      expect(afterCard.isDue, isTrue);
      expect(afterCard.srs.easeFactor, beforeCard.srs.easeFactor);
      expect(afterCard.srs.intervalDays, beforeCard.srs.intervalDays);
      expect(afterCard.srs.repetitions, beforeCard.srs.repetitions);
    });
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
