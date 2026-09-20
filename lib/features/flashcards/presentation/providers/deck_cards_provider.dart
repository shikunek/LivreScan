import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/flashcard.dart';

/// All cards of one deck, newest first (for the word list screen).
final deckCardsProvider =
    FutureProvider.autoDispose.family<List<Flashcard>, int>((ref, deckId) {
  return ref.watch(flashcardRepositoryProvider).getCards(deckId);
});
