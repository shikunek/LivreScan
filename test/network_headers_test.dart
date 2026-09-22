import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livrescan/core/constants.dart';
import 'package:livrescan/core/network/device_id.dart';
import 'package:livrescan/core/network/extraction_api_client.dart';
import 'package:livrescan/core/settings/language_settings.dart';

/// Records the options of the last request and answers with an empty item
/// list, so `ExtractionApiClient` can be exercised without a real server.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode({'items': <dynamic>[]})),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('appKeyHeaders', () {
    test('an empty key adds no header', () {
      expect(appKeyHeaders(''), isEmpty);
    });

    test('a configured key is sent as X-App-Key', () {
      expect(appKeyHeaders('s3cret'), {'X-App-Key': 's3cret'});
    });
  });

  group('deviceIdProvider', () {
    test('generates an id once and keeps returning it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final id = container.read(deviceIdProvider);
      expect(id, hasLength(32));
      expect(prefs.getString('deviceId'), id);

      // A later read (e.g. the next app launch, a fresh container) reuses
      // what's already stored instead of generating a new one.
      final relaunched = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(relaunched.dispose);
      expect(relaunched.read(deviceIdProvider), id);
    });

    test('a fresh install (empty storage) gets its own id', () async {
      SharedPreferences.setMockInitialValues({});
      final firstInstallPrefs = await SharedPreferences.getInstance();
      final first = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(firstInstallPrefs)],
      );
      addTearDown(first.dispose);
      final firstId = first.read(deviceIdProvider);

      // A second install starts from empty storage again.
      SharedPreferences.setMockInitialValues({});
      final secondInstallPrefs = await SharedPreferences.getInstance();
      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(secondInstallPrefs)],
      );
      addTearDown(second.dispose);

      expect(second.read(deviceIdProvider), isNot(firstId));
    });
  });

  group('ExtractionApiClient', () {
    test('sends the device id as X-Device-Id on every request', () async {
      final adapter = _CapturingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      final client = ExtractionApiClient(dio, deviceId: 'device-123');

      await client.extract(text: 'x', sourceLang: 'fr', targetLang: 'cs');

      expect(adapter.lastOptions?.headers['X-Device-Id'], 'device-123');
    });
  });
}
