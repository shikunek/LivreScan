import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/srs/sm2_scheduler.dart';
import '../../domain/entities/flashcard.dart';

/// Holds the due-card queue for one deck's review session. Grading a card
/// updates its SM-2 state on disk and drops it from the in-session queue.
class ReviewController extends FamilyAsyncNotifier<List<Flashcard>, int> {
  @override
  Future<List<Flashcard>> build(int deckId) {
    return ref.read(flashcardRepositoryProvider).getDueCards(deckId);
  }

  Future<void> answer(int cardId, ReviewGrade grade) async {
    await ref.read(flashcardRepositoryProvider).submitReview(cardId, grade);
    final remaining = (state.value ?? const []).where((c) => c.id != cardId).toList();
    state = AsyncData(remaining);
  }
}

final reviewControllerProvider =
    AsyncNotifierProvider.family<ReviewController, List<Flashcard>, int>(ReviewController.new);
