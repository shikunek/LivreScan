import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dio/dio.dart';
import 'package:livrescan/core/settings/language_settings.dart';
import 'package:livrescan/core/srs/sm2_scheduler.dart';
import 'package:livrescan/features/flashcards/domain/entities/flashcard.dart';
import 'package:livrescan/features/scan/domain/entities/scan_destination.dart';
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
    ScanDestination destination = const DefaultDeck(),
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

class _FailingScanController extends ScanController {
  _FailingScanController(this.error);

  final Object error;

  @override
  Future<void> processAndSave({
    required List<Uint8List> images,
    required String sourceLang,
    required String targetLang,
    ScanDestination destination = const DefaultDeck(),
  }) async {
    state = AsyncError(error, StackTrace.empty);
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

  group('errors are explained in plain Czech', () {
    DioException dioError(int status, {Map<String, dynamic>? data}) {
      final options = RequestOptions(path: '/extract');
      return DioException.badResponse(
        statusCode: status,
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: status, data: data),
      );
    }

    Future<void> pumpWithError(WidgetTester tester, Object error) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            scanControllerProvider.overrideWith(() => _FailingScanController(error)),
          ],
          child: MaterialApp(home: ScanResultScreen(images: [Uint8List(0)])),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('429 and 503 say the server is busy', (tester) async {
      await pumpWithError(tester, dioError(429));
      expect(find.textContaining('Server je teď vytížený'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.text('Zkusit znovu'), findsOneWidget);
    });

    testWidgets('a quota_exceeded reason says the free daily pages are used up', (tester) async {
      await pumpWithError(
        tester,
        dioError(
          429,
          data: {
            'detail': {'message': 'Daily free limit of 20 pages reached.', 'reason': 'quota_exceeded'},
          },
        ),
      );
      expect(find.textContaining('Dnešní počet zdarma naskenovaných stránek'), findsOneWidget);
      expect(find.textContaining('Server je teď vytížený'), findsNothing);
    });

    testWidgets('an unauthorized reason asks for an app update', (tester) async {
      await pumpWithError(
        tester,
        dioError(
          401,
          data: {
            'detail': {'message': 'Missing X-Device-Id header.', 'reason': 'unauthorized'},
          },
        ),
      );
      expect(find.textContaining('potřebuje aktualizaci'), findsOneWidget);
    });

    testWidgets('a plain 429 with no reason still says the server is busy', (tester) async {
      await pumpWithError(tester, dioError(429));
      expect(find.textContaining('Server je teď vytížený'), findsOneWidget);
    });

    testWidgets('other server errors say it could not process the page', (tester) async {
      await pumpWithError(tester, dioError(502));
      expect(find.textContaining('Server teď nedokázal stránku zpracovat'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });

    testWidgets('no connection says to check the internet', (tester) async {
      await pumpWithError(
        tester,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/extract'),
          reason: 'offline',
        ),
      );
      expect(find.textContaining('Zkontroluj připojení k internetu'), findsOneWidget);
    });

    testWidgets('unknown errors keep the technical text', (tester) async {
      await pumpWithError(tester, StateError('boom'));
      expect(find.textContaining('Nepodařilo se zpracovat fotky'), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    });
  });
}
