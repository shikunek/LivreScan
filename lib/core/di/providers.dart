import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/flashcards/data/repositories/flashcard_repository_impl.dart';
import '../../features/flashcards/domain/repositories/flashcard_repository.dart';
import '../../features/scan/data/repositories/scan_repository_impl.dart';
import '../../features/scan/domain/repositories/scan_repository.dart';
import '../../features/scan/domain/usecases/scan_page_usecase.dart';
import '../constants.dart';
import '../network/extraction_api_client.dart';
import '../ocr/text_recognizer_service.dart';
import '../srs/sm2_scheduler.dart';
import '../storage/database.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(baseUrl: kBackendBaseUrl));
});

final extractionApiClientProvider = Provider<ExtractionApiClient>((ref) {
  return ExtractionApiClient(ref.watch(dioProvider));
});

final textRecognizerServiceProvider = Provider<TextRecognizerService>((ref) {
  final service = TextRecognizerService();
  ref.onDispose(service.dispose);
  return service;
});

final scanRepositoryProvider = Provider<ScanRepository>((ref) {
  return ScanRepositoryImpl(
    ref.watch(textRecognizerServiceProvider),
    ref.watch(extractionApiClientProvider),
  );
});

final scanPageUseCaseProvider = Provider<ScanPageUseCase>((ref) {
  return ScanPageUseCase(ref.watch(scanRepositoryProvider));
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final sm2SchedulerProvider = Provider<Sm2Scheduler>((ref) => Sm2Scheduler());

final flashcardRepositoryProvider = Provider<FlashcardRepository>((ref) {
  return FlashcardRepositoryImpl(
    ref.watch(appDatabaseProvider),
    ref.watch(sm2SchedulerProvider),
  );
});
