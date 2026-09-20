# LivreScan — architektura

Mobilní appka (Flutter, iOS + Android): vyfotíš stránku knihy → appka
automaticky vytáhne slovíčka a fráze i s překladem a rovnou z nich udělá
kartičky → učíš se je pomocí spaced repetition (SM-2). Žádný ruční výběr —
appka za tebe rozhodne, co stojí za naučení.

## Tok dat

1. Foto stránky (kamera nebo galerie), potvrzení/retake ve `CameraScreen`.
2. On-device OCR (ML Kit, offline, zdarma) → surový text.
3. Text jde na backend `POST /extract`.
4. Backend zavolá Claude API a vrátí seznam kandidátů: slovo/fráze, překlad,
   slovní druh, příkladová věta, CEFR obtížnost.
5. **Appka automaticky uloží všechny vrácené kandidáty** jako `Flashcard`
   do lokální SQLite (Drift) DB, do decku podle jazykové dvojice (vytvoří se
   sám při prvním skenu — `getOrCreateDefaultDeck`).
6. `ScanResultScreen` zobrazí, co se přidalo (jen informativně, nic se tam
   neodklikává).
7. Review obrazovka bere kartičky s `dueDate <= now` a po každé odpovědi
   posouvá SM-2 stav (ease factor, interval, repetitions).

## Struktura `lib/`

```
app/        # MaterialApp.router, go_router routy, theme.dart (paleta, serif, tlačítka)
core/
  ocr/      # TextRecognizerService — wrapper nad ML Kit
  camera/   # GalleryPicker (image_picker fallback ke kameře)
  srs/      # Sm2Scheduler — čistá logika, žádné závislosti na Flutteru/DB
  network/  # ExtractionApiClient (Dio) — volání backendu
  storage/  # Drift AppDatabase (tabulky Decks, Cards → DeckRow/CardRow)
  di/       # providers.dart — Riverpod DI pro celý graf závislostí
  constants.dart  # výchozí jazyky, backend URL (dart-define)
  languages.dart  # seznam podporovaných jazyků (kód, český název, canScan)
  settings/       # LanguageSettingsNotifier — zvolená dvojice jazyků (shared_preferences)
features/
  scan/
    domain/       # VocabCandidate, ScanRepository (abstract), ScanPageUseCase
    data/          # ScanRepositoryImpl (spojuje OCR + API klienta)
    presentation/  # CameraScreen, ScanResultScreen, ScanController (Riverpod)
  flashcards/
    domain/       # Flashcard, Deck, FlashcardRepository (abstract)
    data/          # FlashcardRepositoryImpl nad Drift DB
    presentation/  # DeckListScreen, WordListScreen, ReviewScreen, ReviewController (Riverpod)
shared/            # sdílené widgety napříč features (LanguagePairBar — výběr jazyků)
```

Pravidlo vrstev: `domain` nezná Flutter ani konkrétní DB/síť — jen entity a
rozhraní. `data` implementuje rozhraní nad Drift/Dio/ML Kitem. `presentation`
staví UI nad `domain` přes use-case/repository providery (Riverpod).

`DeckRow`/`CardRow` (ne `Deck`/`Card`) jsou záměrně přejmenované přes
`@DataClassName`, aby se Driftem vygenerované třídy nebily s doménovou
entitou `Deck` a s Flutterovým widgetem `Card`.

## Backend (`backend/`)

Malá FastAPI služba, samostatná od Flutter appky (vlastní `requirements.txt`,
vlastní `.venv`), s jedním endpointem:

```
POST /extract
{ "text": "...", "sourceLang": "fr", "targetLang": "cs", "maxItems": 15 }

→ { "items": [
    { "original": "...", "translation": "...", "type": "word"|"phrase",
      "partOfSpeech": "...", "exampleSentence": "...", "difficulty": "B1" }
  ] }
```

Drží Anthropic API klíč (appka ho nikdy nevidí, viz `backend/.env.example`),
volá Claude (`claude-haiku-4-5-20251001`, přepsatelné přes `LIVRESCAN_MODEL`)
přes vynucené tool-use volání, takže odpověď je vždy validní JSON podle
schématu. `ExtractionApiClient` (`lib/core/network/extraction_api_client.dart`)
je proti tomuto kontraktu napsaný a otestovaný proti běžícímu serveru.
Spuštění a napojení appky (včetně Android emulator caveat s `10.0.2.2`) je
v `backend/README.md`. Auth/rate-limiting zatím žádné — pro lokální vývoj
netřeba, před nasazením do produkce doplnit.

Zkoušeli jsme i Gemini free tier (`google-genai`), ale narazili jsme na
aktuální (2026) rozbitý přechod Googlu na nový formát API klíčů
(`AQ.Ab...`) — `401 ACCESS_TOKEN_TYPE_UNSUPPORTED`/`API_KEY_SERVICE_BLOCKED`
i po povolení API v Google Cloud Console, potvrzeno jako široce hlášený
problém na straně Googlu. Viz `backend/README.md` pro detaily; návrat by
byl snadný, kontrakt `/extract` na tom nezávisí.

## Co je hotové vs. co zbývá

**Hotovo:**
- Flutter projekt, závislosti, feature-first struktura
- `VocabCandidate`, `ScanRepository`, `ScanPageUseCase`
- `TextRecognizerService` (ML Kit OCR)
- `ExtractionApiClient` (Dio → backend kontrakt)
- `ScanRepositoryImpl` (spojuje OCR + API)
- `Sm2Scheduler` (SM-2 algoritmus)
- `Drift` schema (`Decks`, `Cards`) + codegen
- `Flashcard`, `Deck` entity, `FlashcardRepository` rozhraní + `FlashcardRepositoryImpl`
- `CameraScreen` — živý náhled, foto/retake, výběr z galerie
- `ScanResultScreen` + `ScanController` — po vyfocení automaticky OCR →
  extrakce → uložení všech kandidátů, žádný krok navíc od uživatele
- `ReviewScreen` + `ReviewController` — kartička s tap-to-reveal, 3 hodnoticí
  smajlíky (😞 Znovu / 😐 Těžké / 😊 Dobré → SM-2 `again`/`hard`/`good`), fronta
  due karet se po ohodnocení zmenšuje bez nutnosti znovu načítat z DB
- `DeckListScreen` + `decksProvider` — reálné decky z DB (`AsyncNotifier`,
  autoDispose, pull-to-refresh), tap na deck vede na `/deck/:id/review`,
  posun zprava doleva vysune „Smazat“, klepnutí na něj deck smaže (i s kartičkami)
- `WordListScreen` (`/deck/:id/words`) — seznam všech slovíček decku, nejnovější první;
  otevírá se ikonou seznamu v řádku decku
- Výběr jazykové dvojice (`LanguagePairBar`), jeden deck na směrovou dvojici
- DI graf (`core/di/providers.dart`) propojující všechny vrstvy
- Routing (go_router)
- Backend (`backend/`) — FastAPI `/extract`, ověřený lokálním under-testem
  (validace vstupu, volání Claude, health check) i end-to-end z appky
  (Android emulátor → `10.0.2.2` → backend, reálný sken naskenované
  francouzské stránky → 15 kartiček → review se SM-2 hodnocením, vše
  odzkoušené naživo na emulátoru)

**TODO:**
- Ruční vytváření/přejmenování decků v UI (deck se zakládá jen automaticky
  při prvním skenu jazykové dvojice)
- Kontrola duplicit při opakovaném skenu stejné stránky
- Auth/rate-limiting backendu
- Známé omezení: Google ML Kit iOS binárky nemají arm64 slice pro simulátor
  (Apple Silicon) — OCR flow lze živě otestovat jen na reálném iPhonu nebo
  v Android emulátoru/zařízení
