import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../flashcards/domain/entities/flashcard.dart';
import '../../../flashcards/presentation/providers/decks_provider.dart';
import '../../../flashcards/presentation/providers/review_controller.dart';
import '../../domain/entities/vocab_candidate.dart';

/// 1-based index of the page currently being processed, and the total page
/// count for this run. Null while idle. Lets the UI show "page 2 of 3"
/// during a multi-page scan instead of a single opaque spinner.
class ScanProgress {
  const ScanProgress({required this.current, required this.total});

  final int current;
  final int total;
}

final scanProgressProvider = StateProvider<ScanProgress?>((ref) => null);

/// Runs the full scan pipeline (OCR -> backend extraction -> save) for one
/// or more page photos and exposes the resulting flashcards. Selection is
/// fully automatic: every candidate the backend returns gets saved, no user
/// picking involved.
class ScanController extends AsyncNotifier<List<Flashcard>> {
  @override
  List<Flashcard> build() => const [];

  Future<void> processAndSave({
    required List<Uint8List> images,
    required String sourceLang,
    required String targetLang,
  }) async {
    state = const AsyncLoading();
    ref.read(scanProgressProvider.notifier).state = null;

    state = await AsyncValue.guard(() async {
      final scanPageUseCase = ref.read(scanPageUseCaseProvider);
      final allCandidates = <VocabCandidate>[];

      for (var i = 0; i < images.length; i++) {
        ref.read(scanProgressProvider.notifier).state =
            ScanProgress(current: i + 1, total: images.length);
        final candidates = await scanPageUseCase.call(
          imageBytes: images[i],
          sourceLang: sourceLang,
          targetLang: targetLang,
        );
        allCandidates.addAll(candidates);
      }

      final flashcardRepository = ref.read(flashcardRepositoryProvider);
      final deck = await flashcardRepository.getOrCreateDefaultDeck(
        sourceLang: sourceLang,
        targetLang: targetLang,
      );

      final saved = await flashcardRepository.saveCandidates(
        deckId: deck.id,
        candidates: allCandidates,
      );

      // The deck list (still mounted under the scan screens) and this deck's
      // review queue were loaded before these cards/deck existed.
      ref.invalidate(decksProvider);
      ref.invalidate(reviewControllerProvider(deck.id));

      return saved;
    });

    ref.read(scanProgressProvider.notifier).state = null;
  }
}

final scanControllerProvider = AsyncNotifierProvider<ScanController, List<Flashcard>>(
  ScanController.new,
);
