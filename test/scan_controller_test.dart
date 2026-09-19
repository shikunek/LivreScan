import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:livrescan/core/di/providers.dart';
import 'package:livrescan/core/srs/sm2_scheduler.dart';
import 'package:livrescan/features/flashcards/domain/entities/deck.dart';
import 'package:livrescan/features/flashcards/domain/entities/flashcard.dart';
import 'package:livrescan/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:livrescan/features/flashcards/presentation/providers/decks_provider.dart';
import 'package:livrescan/features/flashcards/presentation/providers/review_controller.dart';
import 'package:livrescan/features/scan/domain/entities/vocab_candidate.dart';
import 'package:livrescan/features/scan/domain/repositories/scan_repository.dart';
import 'package:livrescan/features/scan/domain/usecases/scan_page_usecase.dart';
import 'package:livrescan/features/scan/presentation/providers/scan_controller.dart';

class _FakeScanRepository implements ScanRepository {
  @override
  Future<String> recognizeText(Uint8List imageBytes) async => 'some text';

  @override
  Future<List<VocabCandidate>> extractVocabulary({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    return const [
      VocabCandidate(
        original: 'kniha',
        translation: 'book',
        type: VocabType.word,
        exampleSentence: '',
      ),
    ];
  }
}

class _InMemoryFlashcardRepository implements FlashcardRepository {
  final decks = <Deck>[];
  final cards = <Flashcard>[];

  @override
  Future<List<Deck>> getDecks() async => List.of(decks);

  @override
  Future<Deck> createDeck({
    required String name,
    required String sourceLang,
    required String targetLang,
  }) async {
    final deck = Deck(id: decks.length + 1, name: name, sourceLang: sourceLang, targetLang: targetLang);
    decks.add(deck);
    return deck;
  }

  @override
  Future<Deck> getOrCreateDefaultDeck({
    required String sourceLang,
    required String targetLang,
  }) async {
    final existing = decks
        .where((d) => d.sourceLang == sourceLang && d.targetLang == targetLang)
        .firstOrNull;
    return existing ??
        createDeck(name: 'Moje slovíčka', sourceLang: sourceLang, targetLang: targetLang);
  }

  @override
  Future<List<Flashcard>> saveCandidates({
    required int deckId,
    required List<VocabCandidate> candidates,
  }) async {
    final saved = [
      for (final c in candidates)
        Flashcard(
          id: cards.length + 1,
          deckId: deckId,
          original: c.original,
          translation: c.translation,
          type: c.type,
          exampleSentence: c.exampleSentence,
          srs: Sm2State.initial(),
        ),
    ];
    cards.addAll(saved);
    return saved;
  }

  @override
  Future<List<Flashcard>> getDueCards(int deckId) async =>
      cards.where((c) => c.deckId == deckId).toList();

  @override
  Future<void> submitReview(int cardId, ReviewGrade grade) async {}
}

void main() {
  test('scanning refreshes the deck list and the deck review queue', () async {
    final repo = _InMemoryFlashcardRepository();
    final container = ProviderContainer(overrides: [
      flashcardRepositoryProvider.overrideWithValue(repo),
      scanPageUseCaseProvider.overrideWithValue(ScanPageUseCase(_FakeScanRepository())),
    ]);
    addTearDown(container.dispose);

    // Mimic the deck list screen and an already-opened review screen still
    // being mounted (and so keeping their providers alive) during the scan.
    container.listen(decksProvider, (_, _) {});
    expect(await container.read(decksProvider.future), isEmpty);

    Future<void> scan(String source, String target) {
      return container.read(scanControllerProvider.notifier).processAndSave(
            images: [Uint8List(0)],
            sourceLang: source,
            targetLang: target,
          );
    }

    await scan('cs', 'en');
    var decks = await container.read(decksProvider.future);
    expect(decks.map((d) => '${d.sourceLang}→${d.targetLang}'), ['cs→en']);

    // A second pair gets its own deck, and new cards in an existing deck
    // show up in a review queue that was already loaded.
    container.listen(reviewControllerProvider(1), (_, _) {});
    expect(await container.read(reviewControllerProvider(1).future), hasLength(1));

    await scan('fr', 'cs');
    await scan('cs', 'en');

    decks = await container.read(decksProvider.future);
    expect(decks.map((d) => '${d.sourceLang}→${d.targetLang}'), ['cs→en', 'fr→cs']);
    expect(await container.read(reviewControllerProvider(1).future), hasLength(2));
  });
}
