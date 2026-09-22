import 'package:dio/dio.dart';

import '../../features/scan/domain/entities/vocab_candidate.dart';

/// Talks to the LivreScan backend's `POST /extract` endpoint, which calls
/// Claude to pull vocabulary/phrases with translations out of raw OCR text.
class ExtractionApiClient {
  // Not `this._deviceId`: that would make the named parameter private
  // (`_deviceId`), unusable from the other files that construct this.
  // ignore: prefer_initializing_formals
  ExtractionApiClient(this._dio, {required String deviceId}) : _deviceId = deviceId;

  final Dio _dio;

  /// Sent as `X-Device-Id` so the backend can track this install's free
  /// daily scan quota. See `core/network/device_id.dart`.
  final String _deviceId;

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
      options: Options(headers: {'X-Device-Id': _deviceId}),
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
