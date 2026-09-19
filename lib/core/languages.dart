/// A language the user can pick for scanning/translating.
///
/// [canScan] means on-device OCR can read it as a *source* language. The
/// ML Kit text recognizer is set up for Latin script only, so languages in
/// other scripts are offered as translation targets but not as sources.
class AppLanguage {
  const AppLanguage(this.code, this.name, {this.canScan = true});

  /// ISO 639-1 code, sent to the backend as-is.
  final String code;

  /// Czech display name.
  final String name;

  final bool canScan;
}

const kLanguages = <AppLanguage>[
  AppLanguage('fr', 'Francouzština'),
  AppLanguage('en', 'Angličtina'),
  AppLanguage('de', 'Němčina'),
  AppLanguage('es', 'Španělština'),
  AppLanguage('it', 'Italština'),
  AppLanguage('pt', 'Portugalština'),
  AppLanguage('nl', 'Nizozemština'),
  AppLanguage('pl', 'Polština'),
  AppLanguage('cs', 'Čeština'),
  AppLanguage('sk', 'Slovenština'),
  AppLanguage('hu', 'Maďarština'),
  AppLanguage('ro', 'Rumunština'),
  AppLanguage('hr', 'Chorvatština'),
  AppLanguage('sv', 'Švédština'),
  AppLanguage('da', 'Dánština'),
  AppLanguage('no', 'Norština'),
  AppLanguage('fi', 'Finština'),
  AppLanguage('tr', 'Turečtina'),
  AppLanguage('ru', 'Ruština', canScan: false),
  AppLanguage('uk', 'Ukrajinština', canScan: false),
  AppLanguage('ja', 'Japonština', canScan: false),
  AppLanguage('ko', 'Korejština', canScan: false),
  AppLanguage('zh', 'Čínština', canScan: false),
];

/// Looks up a language by code. Falls back to the upper-cased code so decks
/// saved with a code that is no longer in [kLanguages] still render.
AppLanguage languageByCode(String code) {
  return kLanguages.firstWhere(
    (l) => l.code == code,
    orElse: () => AppLanguage(code, code.toUpperCase()),
  );
}
