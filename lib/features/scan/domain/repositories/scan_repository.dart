import 'dart:typed_data';

import '../entities/vocab_candidate.dart';

abstract class ScanRepository {
  /// Runs on-device OCR over a captured page image and returns raw text.
  Future<String> recognizeText(Uint8List imageBytes);

  /// Sends the OCR text to the extraction backend and returns candidate
  /// vocabulary/phrases with translation and example sentences.
  Future<List<VocabCandidate>> extractVocabulary({
    required String text,
    required String sourceLang,
    required String targetLang,
  });
}
