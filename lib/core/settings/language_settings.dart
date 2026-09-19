import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../languages.dart';

const _sourceKey = 'sourceLang';
const _targetKey = 'targetLang';

/// The language pair used for the next scan.
class LanguagePair {
  const LanguagePair({required this.source, required this.target});

  final String source;
  final String target;
}

/// Overridden in `main()` once [SharedPreferences] has been loaded, so the
/// settings notifier can read the saved pair synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

class LanguageSettingsNotifier extends Notifier<LanguagePair> {
  late final SharedPreferences _prefs;

  @override
  LanguagePair build() {
    _prefs = ref.watch(sharedPreferencesProvider);

    final source = _prefs.getString(_sourceKey);
    final target = _prefs.getString(_targetKey);
    final valid = source != null &&
        target != null &&
        source != target &&
        _isKnown(source) &&
        _isKnown(target) &&
        languageByCode(source).canScan;

    return valid
        ? LanguagePair(source: source, target: target)
        : const LanguagePair(source: kDefaultSourceLang, target: kDefaultTargetLang);
  }

  bool _isKnown(String code) => kLanguages.any((l) => l.code == code);

  /// The picker never offers the other side's language, so [code] always
  /// differs from the current target.
  void setSource(String code) => _set(LanguagePair(source: code, target: state.target));

  void setTarget(String code) => _set(LanguagePair(source: state.source, target: code));

  /// Whether the pair can be flipped: the current target has to be readable
  /// by OCR to become the new source.
  bool get canSwap => languageByCode(state.target).canScan;

  void swap() {
    if (!canSwap) return;
    _set(LanguagePair(source: state.target, target: state.source));
  }

  void _set(LanguagePair pair) {
    state = pair;
    _prefs.setString(_sourceKey, pair.source);
    _prefs.setString(_targetKey, pair.target);
  }
}

final languageSettingsProvider =
    NotifierProvider<LanguageSettingsNotifier, LanguagePair>(LanguageSettingsNotifier.new);
