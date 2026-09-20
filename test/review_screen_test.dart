import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:livrescan/core/di/providers.dart';
import 'package:livrescan/core/srs/sm2_scheduler.dart';
import 'package:livrescan/features/flashcards/domain/entities/flashcard.dart';
import 'package:livrescan/features/flashcards/domain/repositories/flashcard_repository.dart';
import 'package:livrescan/features/flashcards/presentation/screens/review_screen.dart';
import 'package:livrescan/features/scan/domain/entities/vocab_candidate.dart';

class _FakeRepository extends Fake implements FlashcardRepository {
  final grades = <ReviewGrade>[];

  @override
  Future<void> submitReview(int cardId, ReviewGrade grade) async => grades.add(grade);

  @override
  Future<List<Flashcard>> getDueCards(int deckId) async => [
        Flashcard(
          id: 1,
          deckId: deckId,
          original: 'courir',
          translation: 'běžet',
          type: VocabType.word,
          exampleSentence: '',
          partOfSpeech: 'verb',
          srs: Sm2State.initial(),
        ),
      ];
}

Future<_FakeRepository> _pumpReview(WidgetTester tester) async {
  final repository = _FakeRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [flashcardRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: ReviewScreen(deckId: 1)),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('review card shows only the word until tapped, then the translation', (tester) async {
    await _pumpReview(tester);

    expect(find.text('courir'), findsOneWidget);
    expect(find.text('slovo'), findsNothing);
    expect(find.text('fráze'), findsNothing);
    expect(find.text('Zobrazit překlad'), findsNothing);
    expect(find.text('běžet'), findsNothing);
    expect(find.text('😊'), findsNothing);

    await tester.tap(find.text('courir'));
    await tester.pumpAndSettle();

    expect(find.text('běžet'), findsOneWidget);
    // Part of speech is no longer shown.
    expect(find.text('verb'), findsNothing);
  });

  // One test per button: each needs a fresh ProviderScope, since answering a
  // card removes it from the (cached) review queue.
  for (final (emoji, grade) in [
    ('😞', ReviewGrade.again),
    ('😐', ReviewGrade.hard),
    ('😊', ReviewGrade.good),
  ]) {
    testWidgets('grading: $emoji submits ${grade.name}, with three buttons and no labels',
        (tester) async {
      final repository = await _pumpReview(tester);
      await tester.tap(find.text('courir'));
      await tester.pumpAndSettle();

      expect(find.text('😞'), findsOneWidget);
      expect(find.text('😐'), findsOneWidget);
      expect(find.text('😊'), findsOneWidget);
      expect(find.text('Znovu'), findsNothing);
      expect(find.text('Lehké'), findsNothing);

      await tester.tap(find.text(emoji));
      await tester.pumpAndSettle();
      expect(repository.grades, [grade]);
    });
  }
}
