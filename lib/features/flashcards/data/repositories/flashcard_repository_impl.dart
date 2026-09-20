import 'package:drift/drift.dart';

import '../../../../core/srs/sm2_scheduler.dart';
import '../../../../core/storage/database.dart';
import '../../../scan/domain/entities/vocab_candidate.dart';
import '../../domain/entities/deck.dart';
import '../../domain/entities/flashcard.dart';
import '../../domain/repositories/flashcard_repository.dart';

class FlashcardRepositoryImpl implements FlashcardRepository {
  FlashcardRepositoryImpl(this._db, this._scheduler);

  final AppDatabase _db;
  final Sm2Scheduler _scheduler;

  @override
  Future<List<Deck>> getDecks() async {
    final rows = await _db.select(_db.decks).get();
    return rows.map(_deckFromRow).toList();
  }

  @override
  Future<Deck> createDeck({
    required String name,
    required String sourceLang,
    required String targetLang,
  }) async {
    final id = await _db.into(_db.decks).insert(
          DecksCompanion.insert(
            name: name,
            sourceLang: sourceLang,
            targetLang: targetLang,
          ),
        );
    return Deck(id: id, name: name, sourceLang: sourceLang, targetLang: targetLang);
  }

  @override
  Future<void> deleteDeck(int deckId) {
    return _db.transaction(() async {
      await (_db.delete(_db.cards)..where((c) => c.deckId.equals(deckId))).go();
      await (_db.delete(_db.decks)..where((d) => d.id.equals(deckId))).go();
    });
  }

  @override
  Future<Deck> getOrCreateDefaultDeck({
    required String sourceLang,
    required String targetLang,
  }) async {
    final existing = await (_db.select(_db.decks)
          ..where((d) => d.sourceLang.equals(sourceLang) & d.targetLang.equals(targetLang))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return _deckFromRow(existing);

    return createDeck(
      name: 'Moje slovíčka',
      sourceLang: sourceLang,
      targetLang: targetLang,
    );
  }

  @override
  Future<List<Flashcard>> saveCandidates({
    required int deckId,
    required List<VocabCandidate> candidates,
  }) async {
    return _db.transaction(() async {
      final saved = <Flashcard>[];
      for (final candidate in candidates) {
        final id = await _db.into(_db.cards).insert(
              CardsCompanion.insert(
                deckId: deckId,
                original: candidate.original,
                translation: candidate.translation,
                type: candidate.type.name,
                exampleSentence: Value(candidate.exampleSentence),
                partOfSpeech: Value(candidate.partOfSpeech),
              ),
            );
        saved.add(Flashcard(
          id: id,
          deckId: deckId,
          original: candidate.original,
          translation: candidate.translation,
          type: candidate.type,
          exampleSentence: candidate.exampleSentence,
          partOfSpeech: candidate.partOfSpeech,
          srs: Sm2State.initial(),
        ));
      }
      return saved;
    });
  }

  @override
  Future<List<Flashcard>> getCards(int deckId) async {
    final rows = await (_db.select(_db.cards)
          ..where((c) => c.deckId.equals(deckId))
          ..orderBy([(c) => OrderingTerm.desc(c.id)]))
        .get();
    return rows.map(_flashcardFromRow).toList();
  }

  @override
  Future<List<Flashcard>> getDueCards(int deckId) async {
    final now = DateTime.now();
    final rows = await (_db.select(_db.cards)
          ..where((c) => c.deckId.equals(deckId) & c.dueDate.isSmallerOrEqualValue(now)))
        .get();
    return rows.map(_flashcardFromRow).toList();
  }

  @override
  Future<void> submitReview(int cardId, ReviewGrade grade) async {
    final row = await (_db.select(_db.cards)..where((c) => c.id.equals(cardId))).getSingle();
    final current = Sm2State(
      easeFactor: row.easeFactor,
      intervalDays: row.intervalDays,
      repetitions: row.repetitions,
      dueDate: row.dueDate,
    );
    final next = _scheduler.next(current, grade);
    await (_db.update(_db.cards)..where((c) => c.id.equals(cardId))).write(
      CardsCompanion(
        easeFactor: Value(next.easeFactor),
        intervalDays: Value(next.intervalDays),
        repetitions: Value(next.repetitions),
        dueDate: Value(next.dueDate),
      ),
    );
  }

  Deck _deckFromRow(DeckRow row) => Deck(
        id: row.id,
        name: row.name,
        sourceLang: row.sourceLang,
        targetLang: row.targetLang,
      );

  Flashcard _flashcardFromRow(CardRow row) => Flashcard(
        id: row.id,
        deckId: row.deckId,
        original: row.original,
        translation: row.translation,
        type: row.type == 'phrase' ? VocabType.phrase : VocabType.word,
        exampleSentence: row.exampleSentence,
        partOfSpeech: row.partOfSpeech,
        srs: Sm2State(
          easeFactor: row.easeFactor,
          intervalDays: row.intervalDays,
          repetitions: row.repetitions,
          dueDate: row.dueDate,
        ),
      );
}
