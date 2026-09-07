import 'dart:typed_data';

import '../../../../core/network/extraction_api_client.dart';
import '../../../../core/ocr/text_recognizer_service.dart';
import '../../domain/entities/vocab_candidate.dart';
import '../../domain/repositories/scan_repository.dart';

class ScanRepositoryImpl implements ScanRepository {
  ScanRepositoryImpl(this._ocr, this._api);

  final TextRecognizerService _ocr;
  final ExtractionApiClient _api;

  @override
  Future<String> recognizeText(Uint8List imageBytes) {
    return _ocr.recognize(imageBytes);
  }

  @override
  Future<List<VocabCandidate>> extractVocabulary({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) {
    return _api.extract(
      text: text,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );
  }
}
