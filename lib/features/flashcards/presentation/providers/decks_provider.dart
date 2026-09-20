import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/deck.dart';
import 'review_controller.dart';

class DecksNotifier extends AutoDisposeAsyncNotifier<List<Deck>> {
  @override
  Future<List<Deck>> build() {
    return ref.watch(flashcardRepositoryProvider).getDecks();
  }

  /// Removes the deck from the list right away (a swiped-away `Dismissible`
  /// has to leave the tree synchronously) and deletes it from storage after.
  /// Returns false, and brings the deck back, if the deletion failed.
  Future<bool> delete(int deckId) async {
    final current = state.valueOrNull ?? const <Deck>[];
    state = AsyncData(current.where((d) => d.id != deckId).toList());

    try {
      await ref.read(flashcardRepositoryProvider).deleteDeck(deckId);
      ref.invalidate(reviewControllerProvider(deckId));
      return true;
    } catch (_) {
      ref.invalidateSelf();
      return false;
    }
  }
}

final decksProvider = AsyncNotifierProvider.autoDispose<DecksNotifier, List<Deck>>(
  DecksNotifier.new,
);
