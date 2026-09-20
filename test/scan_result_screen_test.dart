import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livrescan/core/settings/language_settings.dart';
import 'package:livrescan/core/srs/sm2_scheduler.dart';
import 'package:livrescan/features/flashcards/domain/entities/flashcard.dart';
import 'package:livrescan/features/scan/domain/entities/vocab_candidate.dart';
import 'package:livrescan/features/scan/presentation/providers/scan_controller.dart';
import 'package:livrescan/features/scan/presentation/screens/scan_result_screen.dart';

/// Skips OCR/backend/storage and just returns a fixed card.
class _FakeScanController extends ScanController {
  @override
  Future<void> processAndSave({
    required List<Uint8List> images,
    required String sourceLang,
    required String targetLang,
  }) async {
    state = AsyncData([
      Flashcard(
        id: 1,
        deckId: 1,
        original: 'courir',
        translation: 'běžet',
        type: VocabType.word,
        exampleSentence: 'Il aime courir le matin.',
        srs: Sm2State.initial(),
      ),
    ]);
  }
}

void main() {
  testWidgets('scan result lists word and translation but hides the example sentence',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          scanControllerProvider.overrideWith(_FakeScanController.new),
        ],
        child: MaterialApp(home: ScanResultScreen(images: [Uint8List(0)])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('courir'), findsOneWidget);
    expect(find.text('běžet'), findsOneWidget);
    expect(find.text('Il aime courir le matin.'), findsNothing);
  });
}
