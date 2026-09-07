import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../flashcards/domain/entities/flashcard.dart';

/// Runs the full scan pipeline (OCR -> backend extraction -> save) and
/// exposes the resulting flashcards. Selection is fully automatic: every
/// candidate the backend returns gets saved, no user picking involved.
class ScanController extends AsyncNotifier<List<Flashcard>> {
  @override
  List<Flashcard> build() => const [];

  Future<void> processAndSave({
    required Uint8List imageBytes,
    required String sourceLang,
    required String targetLang,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final candidates = await ref.read(scanPageUseCaseProvider).call(
            imageBytes: imageBytes,
            sourceLang: sourceLang,
            targetLang: targetLang,
          );

      final flashcardRepository = ref.read(flashcardRepositoryProvider);
      final deck = await flashcardRepository.getOrCreateDefaultDeck(
        sourceLang: sourceLang,
        targetLang: targetLang,
      );

      return flashcardRepository.saveCandidates(
        deckId: deck.id,
        candidates: candidates,
      );
    });
  }
}

final scanControllerProvider = AsyncNotifierProvider<ScanController, List<Flashcard>>(
  ScanController.new,
);
