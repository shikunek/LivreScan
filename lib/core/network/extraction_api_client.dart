import 'package:dio/dio.dart';

import '../../features/scan/domain/entities/vocab_candidate.dart';

/// Talks to the LivreScan backend's `POST /extract` endpoint, which calls
/// Claude to pull vocabulary/phrases with translations out of raw OCR text.
class ExtractionApiClient {
  ExtractionApiClient(this._dio);

  final Dio _dio;

  Future<List<VocabCandidate>> extract({
    required String text,
    required String sourceLang,
    required String targetLang,
    int maxItems = 15,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/extract',
      data: {
        'text': text,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'maxItems': maxItems,
      },
    );

    final items = (response.data?['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return items.map((item) {
      return VocabCandidate(
        original: item['original'] as String,
        translation: item['translation'] as String,
        type: item['type'] == 'phrase' ? VocabType.phrase : VocabType.word,
        exampleSentence: item['exampleSentence'] as String? ?? '',
        partOfSpeech: item['partOfSpeech'] as String?,
        difficulty: _parseCefr(item['difficulty'] as String?),
      );
    }).toList();
  }

  Cefr? _parseCefr(String? raw) {
    if (raw == null) return null;
    return Cefr.values.where((c) => c.name == raw.toLowerCase()).firstOrNull;
  }
}
