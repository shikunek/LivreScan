import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/language_settings.dart';

const _deviceIdKey = 'deviceId';

/// A random id generated once per install and stored locally. The backend
/// uses it to track this install's free daily scan quota -- it identifies
/// the install, not the person, and goes nowhere except as a request header
/// to LivreScan's own backend.
final deviceIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final existing = prefs.getString(_deviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final id = _generateId();
  prefs.setString(_deviceIdKey, id);
  return id;
});

String _generateId() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
}
