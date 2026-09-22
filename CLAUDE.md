# LivreScan

Flutter appka (iOS + Android): vyfotíš stránku knihy → OCR → backend přes LLM
vytáhne slovíčka s překladem → uloží se jako kartičky → učení přes SM-2.
Uživatel je Čech, **UI texty jsou česky**, komunikuj česky.

Architektura a tok dat: [ARCHITECTURE.md](ARCHITECTURE.md). Backend (FastAPI,
Azure): [backend/README.md](backend/README.md). Tady jsou jen věci, které z kódu
nevyčteš.

## Spuštění na iPhonu (release)

Zařízení: `Petr - iPhone (2)`, UDID `00008110-000A043A1E45801E`, bundle ID
`com.livrescan.livrescan`, tým `39HSWYVHN5` (podpis je automatický).

```bash
flutter run --release -d 00008110-000A043A1E45801E
```

- Pokud `flutter run` selže při „Installing and launching“ (obecná chyba, build
  je v pořádku), sestav a nainstaluj ručně:
  `flutter build ios --release`, pak
  `xcrun devicectl device install app --device <UDID> build/ios/iphoneos/Runner.app`
  a `xcrun devicectl device process launch --terminate-existing --device <UDID> com.livrescan.livrescan`.
  Nezůstane tak viset proces na pozadí.
- V release režimu nefunguje hot reload; po změně se nasazuje znovu.
- Na telefon nasazuj, až když o to uživatel požádá.
- Ruční `pod install` potřebuje `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`, jinak
  CocoaPods spadne na chybě kódování.
- `ios/Podfile` má v `post_install` zvednutí `IPHONEOS_DEPLOYMENT_TARGET` všech
  Pods pod 15.5 na 15.5. Bez toho build na nové Xcode selže (Target Integrity).
- MLKit nemá arm64 pro simulátor, appka jede jen na fyzickém zařízení. Simulátor
  navíc nemá kameru.

## Před dokončením práce

`flutter analyze` (musí být bez issues) a `flutter test`. Po změně Drift schématu
(`lib/core/storage/database.dart`): `dart run build_runner build --delete-conflicting-outputs`.

## Jazyky a decky

- Vybraná dvojice jazyků: `LanguageSettingsNotifier`
  ([lib/core/settings/language_settings.dart](lib/core/settings/language_settings.dart)),
  ukládá se přes `shared_preferences`; seznam jazyků je v
  [lib/core/languages.dart](lib/core/languages.dart). UI: `LanguagePairBar`.
- Decky mají **směrovou** dvojici jazyků (fr→cs a cs→fr jsou různé), ale dvojice může
  mít víc decků. Po „Hotovo“ v kameře se `chooseScanDestination` zeptá, kam
  slovíčka uložit (nový deck s názvem, nebo existující); s prázdným seznamem se
  neptá a použije `getOrCreateDefaultDeck`. Deck vzniká až po zpracování, když se
  něco našlo (prázdný sken žádný deck nezaloží), a ne při přepnutí jazyka.
- Zdrojový jazyk smí být jen latinkový (`canScan`): `TextRecognizer` je nastavený
  na `TextRecognitionScript.latin`. CJK/devanágarí by potřebovaly další pody na iOS
  a gradle závislosti na Androidu (viz README pluginu google_mlkit_text_recognition).
  Cílový jazyk může být libovolný.

## Vzhled

Kombinace klidného stylu (krémové pozadí, jeden hlinitý akcent, patkové písmo)
a iOS ovládání. Barvy (`AppColors`), `serifStyle()` a `pillButtonStyle` jsou v
[lib/app/theme.dart](lib/app/theme.dart); nepoužívej natvrdo `Colors.*` pro věci,
které mají být v paletě. Výběr jazyka je `CupertinoActionSheet`, mazání decku je
`Slidable` (`flutter_slidable`): posun zprava doleva vysune „Smazat“, klepnutí smaže
bez dalšího dialogu; `SlidableAutoCloseBehavior` kolem seznamu zavírá ostatní řádky, seznam decků má bounce scroll a
`CupertinoSliverRefreshControl`, hlavní akce je tlačítko dole (ne FAB). Haptika přes
`HapticFeedback`. Titulek `AppBar` z tématu je tmavý (`foregroundColor` se na něj
neaplikuje), takže na černé obrazovce kamery má explicitně bílý styl.

## Pasti

- Po skenu se musí zneplatnit `decksProvider` a `reviewControllerProvider(deckId)`
  (dělá to `ScanController`). Seznam decků zůstává v navigátoru pod scan
  obrazovkami, jinak drží starý výsledek a nový deck se nezobrazí. Kryje to
  `test/scan_controller_test.dart`.
- `CameraPreview` **neobaluj** do vlastního `AspectRatio` — poměr stran si řeší
  sám podle orientace, jinak se obraz zdeformuje. Rozlišení je `ultraHigh`; kdyby
  náhled na starším telefonu sekal, stačí `veryHigh`. Náhled kamery nejde ověřit
  v simulátoru, ověřuje ho uživatel na telefonu.
- Backend URL se přepisuje `--dart-define=LIVRESCAN_BACKEND_URL=...`
  (výchozí je Azure `livrescan-backend`, viz `lib/core/constants.dart`).
- `/extract` vyžaduje `X-Device-Id` (appka si ho sama vygeneruje a uloží,
  `core/network/device_id.dart`) a kontroluje denní kvótu na zařízení;
  volitelně i `X-App-Key`, pokud je appka sestavená s
  `--dart-define=LIVRESCAN_APP_KEY=...`. Detaily a bezpečné pořadí nasazení
  (aby se neodřízla appka, co už lidi mají nainstalovanou) jsou v
  [backend/README.md](backend/README.md#auth-a-kvóty).
- Volitelné sledování chyb přes Sentry (`SENTRY_DSN`, prázdné = vypnuto). Nikdy
  nenastavuj při testech. Detaily a proč `max_request_body_size` samo nestačilo
  (lokální proměnné ve stack trace jinak posílají naskenovaný text) jsou v
  [backend/README.md](backend/README.md#sledování-chyb).
- Kartičky se nededuplikují: opakovaný sken stejné stránky uloží slovíčka znovu
  (kontrola duplicit zatím neexistuje).
