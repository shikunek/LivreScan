import 'dart:typed_data';

import '../entities/vocab_candidate.dart';
import '../repositories/scan_repository.dart';

/// Orchestrates one full scan: photo -> OCR -> backend extraction.
class ScanPageUseCase {
  ScanPageUseCase(this._repository);

  final ScanRepository _repository;

  Future<List<VocabCandidate>> call({
    required Uint8List imageBytes,
    required String sourceLang,
    required String targetLang,
  }) async {
    final text = await _repository.recognizeText(imageBytes);
    if (text.trim().isEmpty) return const [];
    return _repository.extractVocabulary(
      text: text,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );
  }
}
