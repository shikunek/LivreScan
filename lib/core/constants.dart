// Placeholder defaults until the app has a language-selection UI.
const kDefaultSourceLang = 'fr';
const kDefaultTargetLang = 'cs';

/// Base URL of the LivreScan backend that proxies extraction to Claude.
/// Override at build time with `--dart-define=LIVRESCAN_BACKEND_URL=...`.
const kBackendBaseUrl = String.fromEnvironment(
  'LIVRESCAN_BACKEND_URL',
  defaultValue: 'http://localhost:8787',
);
