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
