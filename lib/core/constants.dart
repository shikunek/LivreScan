// Language pair used until the user picks their own (see LanguagePairBar).
const kDefaultSourceLang = 'fr';
const kDefaultTargetLang = 'cs';

/// Base URL of the LivreScan backend that proxies vocabulary extraction.
/// Deployed to Azure App Service (Free F1 tier, plain Python/zip deploy --
/// no container, no registry, $0/month) so the app works from anywhere,
/// not just on the same Wi-Fi as a locally-running backend. Override at
/// build time with `--dart-define=LIVRESCAN_BACKEND_URL=...` (e.g. for
/// pointing at `http://localhost:8787` during backend development).
const kBackendBaseUrl = String.fromEnvironment(
  'LIVRESCAN_BACKEND_URL',
  defaultValue: 'https://livrescan-backend.azurewebsites.net',
);

/// Shared secret sent as the `X-App-Key` header so the backend can tell a
/// request from this app apart from someone who just found the URL. Baked in
/// at build time with `--dart-define=LIVRESCAN_APP_KEY=...`; empty by
/// default, which matches the backend's default of not requiring one. See
/// backend/README.md for how the key is generated and rolled out.
const kAppKey = String.fromEnvironment('LIVRESCAN_APP_KEY');

/// Pulled out of [kAppKey] so this (otherwise compile-time-constant) piece
/// of logic is testable without needing a `--dart-define` in the test
/// runner.
Map<String, String> appKeyHeaders(String appKey) =>
    appKey.isEmpty ? const {} : {'X-App-Key': appKey};
