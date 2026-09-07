import '../../../scan/domain/entities/vocab_candidate.dart';
import '../../../../core/srs/sm2_scheduler.dart';
import '../entities/deck.dart';
import '../entities/flashcard.dart';

abstract class FlashcardRepository {
  Future<List<Deck>> getDecks();

  Future<Deck> createDeck({
    required String name,
    required String sourceLang,
    required String targetLang,
  });

  /// Returns the deck for this language pair, creating it on first use.
  /// Lets the scan flow save cards without the user having to pick/create
  /// a deck by hand.
  Future<Deck> getOrCreateDefaultDeck({
    required String sourceLang,
    required String targetLang,
  });

  /// Saves every candidate as a new flashcard and returns the saved cards.
  Future<List<Flashcard>> saveCandidates({
    required int deckId,
    required List<VocabCandidate> candidates,
  });

  Future<List<Flashcard>> getDueCards(int deckId);

  Future<void> submitReview(int cardId, ReviewGrade grade);
}
