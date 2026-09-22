# LivreScan backend

Malá FastAPI služba s jedním endpointem `POST /extract`. Přijme OCR text
z appky, zavolá LLM a vrátí seznam slovíček/frází s překladem — appka
sama žádný API klíč nemá, ten zůstává jen tady na serveru.

Extrakci lze přepnout proměnnou `LIVRESCAN_PROVIDER` v `.env` (v repu
defaultně `mock`; na Azure i lokálně u vývojáře aktuálně nastaveno na
`groq` — po vyzkoušení obojího v appce se ukázalo, že desítky sekund
čekání po vyfocení u OpenRouteru jsou pro reálné použití neúnosné,
i když kvalita byla o něco lepší):

| Provider | Cena | Rychlost | Kvalita | Poznámka |
|---|---|---|---|---|
| `mock` | zdarma | okamžitě | fake data | žádné volání ven, pro testování appky |
| `groq` | zdarma, bez karty | **~1,5–2 s** | dobrá, občas špatný idiom | `GROQ_API_KEY`, model `openai/gpt-oss-120b` — **aktuálně používané** |
| `openrouter` | zdarma, bez karty | 55–115 s (sdílený pool) | nejlepší z free, konzistentní i na delším textu | `OPENROUTER_API_KEY`, model `nvidia/nemotron-3-super-120b-a12b:free` nebo `nex-agi/nex-n2.5-pro:free` — příliš pomalé na běžné použití v appce |
| `claude` | placené | rychlé | nejlepší | `ANTHROPIC_API_KEY` |

Ověřeno naživo (Android emulátor i iPhone): reálná fotka francouzské
stránky → kartičky se správnými překlady za ~1,5 s s Groqem. Idiomy
(`à verse` apod.) občas nevyjdou úplně přesně — to je vědomý kompromis
za rychlost; přepnutí zpět na `openrouter` je jen změna proměnné
prostředí, bez redeploy (`az webapp config appsettings set -n
livrescan-backend -g livrescan-rg --settings LIVRESCAN_PROVIDER=openrouter`).

**Limit free tieru Groqu:** `gpt-oss-120b` má 8 000 tokenů za minutu a jedna
stránka jich spotřebuje ~2 800, takže se vejdou zhruba 2–3 stránky za minutu.
Při překročení Groq vrátí `429`; backend na to čeká podle `Retry-After` a
zkusí to znovu (až 6×), takže víc stránek za sebou jen trvá déle. Když to
přesto nevyjde, appce vrací `429` (vytížený model) nebo `502`, ne holou `500`.
Občasné `400 tool_use_failed` (model si vymyslel neplatný `type`) se opakuje
až 3×.

## Testy

```bash
cd backend
python -m unittest discover -s tests -v
```

Běží i v GitHub Actions před každým nasazením.

## Spuštění lokálně

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

cp .env.example .env
# do .env vlož svůj skutečný klíč: ANTHROPIC_API_KEY=sk-ant-...

uvicorn app.main:app --port 8787 --reload
```

Ověření, že běží:

```bash
curl http://localhost:8787/health
```

## Jak appku nasměrovat na tenhle server

Flutter appka čte backend URL z `LIVRESCAN_BACKEND_URL` (default
`http://localhost:8787`, viz `lib/core/constants.dart`).

- **iOS Simulátor**: `localhost:8787` funguje rovnou (sdílí síť s Macem).
- **Android emulátor**: `localhost` z pohledu emulátoru je emulátor sám,
  ne tvůj Mac. Spusť appku takhle:
  ```bash
  flutter run --dart-define=LIVRESCAN_BACKEND_URL=http://10.0.2.2:8787
  ```
- **Reálné zařízení** (iPhone/Android po USB/Wi-Fi): potřebuješ IP adresu
  Macu v lokální síti, např.:
  ```bash
  flutter run --dart-define=LIVRESCAN_BACKEND_URL=http://192.168.1.23:8787
  ```

## Auth a kvóty

`/extract` (ne `/health`) vyžaduje dvě hlavičky:

- **`X-Device-Id`** — libovolný neprázdný řetězec, appka si při prvním
  spuštění vygeneruje náhodné ID a uloží ho lokálně
  (`lib/core/network/device_id.dart`). Podle něj se počítá denní kvóta na
  zařízení (`LIVRESCAN_DAILY_PAGE_LIMIT`, výchozí 20 stránek/den, `<= 0`
  kvótu vypne). Kvóta se drží v SQLite (`app/quota.py`) — na Azure v
  `/home/data/usage.db` (přežije restart kontejneru, běžný soubor by
  nepřežil), lokálně `backend/usage.db` (gitignored).
- **`X-App-Key`** — sdílený klíč appky, kontroluje se, jen když je na
  serveru nastavená proměnná `LIVRESCAN_APP_KEY` (výchozí prázdná = bez
  kontroly). Appka ho posílá jen pokud byla sestavená s
  `--dart-define=LIVRESCAN_APP_KEY=...` (viz `lib/core/constants.dart`).

Chybějící/špatná hlavička vrací `401`, vyčerpaná kvóta `429` — appka to
ukazuje jako srozumitelnou hlášku
(`lib/features/scan/presentation/screens/scan_result_screen.dart`).

**Tohle je lehká obrana, ne kryptografické ověření appky.** `X-App-Key` je
napevno v appce a jde z ní vytáhnout zpětnou analýzou; `X-Device-Id` si
appka volí sama, takže ho jde napodobit. Zabrání to náhodnému zneužití
(kdokoli, kdo zná URL a zavolá ji curlem), ne cílenému útoku. Silnější
ochrana (Apple App Attest / Android Play Integrity) je až budoucí krok,
pokud appka půjde do širšího provozu.

**Nasazování `LIVRESCAN_APP_KEY` — pořadí, ať se appka nerozbije:**
1. Nasadit tenhle backend (kontrola klíče je podmíněná, dokud proměnná
   není nastavená, nic se nezmění).
2. Sestavit a vydat appku s `--dart-define=LIVRESCAN_APP_KEY=<stejná
   hodnota>` a počkat, až ji budou mít nainstalovanou uživatelé.
3. Teprve pak nastavit `LIVRESCAN_APP_KEY` na živém App Service
   (`az webapp config appsettings set -n livrescan-backend -g
   livrescan-rg --settings LIVRESCAN_APP_KEY=...`). Před krokem 2 by tenhle
   krok odřízl i appku, co si sama sedíš na telefonu.

## Sledování chyb

Volitelné, přes [Sentry](https://sentry.io) (free tier: 5 000 chyb/měsíc, 30
dní historie). Zapíná se proměnnou `SENTRY_DSN` -- prázdná (výchozí) = úplně
vypnuto, žádný kód se nespouští, nic nikam nejde (`configure_sentry("")` je
no-op, `tests/test_sentry.py` to ověřuje). **Nikdy nenastavuj `SENTRY_DSN`
při spouštění testů** -- posílaly by se tam syntetické testovací výjimky.

Co se tam dostane: `logger.exception(...)` volání (typ chyby a traceback,
Sentry na ně naváže automaticky přes standardní `logging`, žádný extra kód
navíc) a `logger.warning(...)` jako kontext k nim. Ke každé chybě se přidá
tag `device_id` (`X-Device-Id`, anonymní ID zařízení -- viz „Auth a
kvóty“), takže jde poznat, jestli chybu dělá jedno zařízení opakovaně, nebo
je to plošné.

Co se tam **nedostane**, záměrně a ověřeno testem
(`test_a_failure_does_not_leak_the_scanned_text_into_the_event`): text
naskenované stránky. Sentry defaultně ke každé chybě přikládá i hodnoty
lokálních proměnných ve stack trace -- v `extract()` by to znamenalo poslat
celý sken cizí službě, mimo samotné LLM. Řeší to `include_local_variables=
False` v `configure_sentry()`. (`max_request_body_size="never"` samo o sobě
tohle nestačí vyřešit -- to jsem si nejdřív myslel a ověřením zjistil, že
ne, proto to řeší obě nastavení zvlášť.) Hlavička `X-App-Key` se navíc ručně
škrábe (`_scrub_before_send`), kdyby se někdy zachytávaly i hlavičky
požadavku.

Performance tracing je vypnutý (`traces_sample_rate=0.0`) -- zajímají nás
jen chyby, ne rychlost, a šetří to samostatnou (menší) kvótu na
"transactions" ve free tieru.

## Endpoint

```
POST /extract
{ "text": "...", "sourceLang": "fr", "targetLang": "cs", "maxItems": 15 }

→ 200 { "items": [
    { "original": "...", "translation": "...", "type": "word"|"phrase",
      "partOfSpeech": "...", "exampleSentence": "...", "difficulty": "B1" }
  ] }
```

Extrakce jede přes vynucené strukturované volání nástroje/JSON schématu
(liší se podle providera — tool-use u Claude/Groq, JSON instrukce v
promptu u OpenRouteru), takže odpověď je vždy validní JSON podle schématu
`VocabItem`, ne volný text k parsování.

Model pro každého providera jde přepsat proměnnou prostředí:
`LIVRESCAN_MODEL` (claude), `LIVRESCAN_GROQ_MODEL` (groq),
`LIVRESCAN_OPENROUTER_MODEL` (openrouter).

## Proč ne Gemini / GitHub Models / Microsoft Phi-4

Zkoušeli jsme několik cest ke zdarma extrakci:

- **Gemini free tier** — Google je uprostřed přechodu na nový formát API
  klíčů (`AQ.Ab...` místo `AIzaSy...`) a nový formát je rozbitý — volání
  skončí na `401 ACCESS_TOKEN_TYPE_UNSUPPORTED` / `API_KEY_SERVICE_BLOCKED`
  i po povolení API v Google Cloud Console. Široce hlášený problém na
  straně Googlu, ne něco opravitelného tady.
- **GitHub Models** — kompletně zrušeno k 30. 7. 2026 (viz
  [GitHub Changelog](https://github.blog/changelog/2026-07-30-github-models-is-now-retired/)).
  Endpoint `models.github.ai/inference` vrací `410
  github_models_retirement_brownout` bez ohledu na platnost tokenu.
- **`microsoft/phi-4` na OpenRouteru** — existuje a funguje, ale není
  zdarma (`$0.07`/`$0.14` za milion tokenů podle jejich API) a žádná
  `:free` varianta Phi-4 v katalogu není, i když to tak podle několika
  článků na webu vypadalo — ověřeno omylem až přímým dotazem na
  `GET /api/v1/models`, ne z blogpostů.

- **Groq free tier** — funguje a je rychlý (vlastní LPU hardware), ale
  `llama-3.3-70b-versatile` zmizel z jejich katalogu (žádný obecný Llama
  chat model tam teď není) — použili jsme `openai/gpt-oss-120b` místo něj.
- **`google/gemma-4-31b-it:free` a `-26b-a4b-it:free` na OpenRouteru** —
  cena skutečně `0`/`0`, ale oba jedou přes stejný sdílený pool "Google AI
  Studio", který je často přetížený (`429 upstream_provider_shared_pool`).

Nakonec používáme **`groq`** jako default (rychlost) s `openrouter`
(`nex-agi/nex-n2.5-pro:free` nebo NVIDIA Nemotron) jako záložní volbou pro
vyšší kvalitu, když čas nehraje roli. Kontrakt `/extract` je nezávislý na
tom, co běží uvnitř — přechod na jiný provider je jen o doplnění dalšího
`EXTRACTORS["..."]` v `app/main.py`.

## Nasazení — Azure App Service (Free F1, $0/měsíc)

Backend běží na `https://livrescan-backend.azurewebsites.net`, appka na
tuhle URL míří defaultně (viz `lib/core/constants.dart`). Žádný Docker,
žádný container registry — jen obyčejný Python zip-deploy.

Založení (jednorázově):

```bash
az appservice plan create --name livrescan-plan -g livrescan-rg \
  --sku F1 --is-linux --location westeurope
az webapp create -g livrescan-rg --plan livrescan-plan \
  --name livrescan-backend --runtime "PYTHON:3.12"
az webapp config set -n livrescan-backend -g livrescan-rg \
  --startup-file "uvicorn app.main:app --host 0.0.0.0 --port 8000"
az webapp config appsettings set -n livrescan-backend -g livrescan-rg --settings \
  LIVRESCAN_PROVIDER=groq GROQ_API_KEY=... OPENROUTER_API_KEY=... \
  ANTHROPIC_API_KEY=... SCM_DO_BUILD_DURING_DEPLOYMENT=true
```

Redeploy po změně kódu:

```bash
cd backend
zip -r /tmp/livrescan_backend.zip app requirements.txt -x "*.pyc" -x "__pycache__/*"
az webapp deploy -g livrescan-rg -n livrescan-backend \
  --src-path /tmp/livrescan_backend.zip --type zip
```

### Automatické nasazení (GitHub Actions)

Workflow [`.github/workflows/deploy-backend.yml`](../.github/workflows/deploy-backend.yml)
nasadí backend při každém pushi do `main`, který změní něco v `backend/`
(jde ho pustit i ručně z větve `main`: Actions → „Deploy backend to Azure“ →
Run workflow). Před nasazením ověří, že se `app.main` naimportuje, zabalí
totéž co ruční zip-deploy výš (jen `app` a `requirements.txt`, žádné `.env`
ani `.venv`), nasadí přes `az webapp deploy` a po nasazení zavolá `/health`.

Přihlášení do Azure je **OIDC (bez hesla)**: GitHub při běhu vystaví token a
Azure mu důvěřuje jen pro tenhle repozitář a větev `main`. Publish profile ani
SCM basic auth se nepoužívá (basic auth je na aplikaci vypnuté a má být).

V Azure už je všechno připravené: identita `oidc-msi-8884` ve skupině
`livrescan-rg` (vytvořil ji průvodce Deployment Center) má federovaný přístup
pro `main` tohoto repa a roli `Website Contributor` na `livrescan-backend`.
Nic dalšího zakládat nemusíš. Do GitHubu (Settings → Secrets and variables →
Actions → New repository secret) stačí uložit tři hodnoty, které nejsou tajné
jako heslo, ale patří do secretů:

| Secret | Hodnota zjistíš |
|---|---|
| `AZURE_CLIENT_ID` | `az identity show -g livrescan-rg -n oidc-msi-8884 --query clientId -o tsv` |
| `AZURE_TENANT_ID` | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | `az account show --query id -o tsv` |

Klíče k LLM providerům (`GROQ_API_KEY` apod.) a `LIVRESCAN_PROVIDER` zůstávají
v Azure app settings, workflow je nemění a nepotřebuje.

Poznámky:
- Federovaný přístup je vázaný na `refs/heads/main`, takže ruční běh z jiné
  větve se nepřihlásí.
- Subject v té identitě je ve formátu s ID (`repo:<owner>@<id>/<repo>@<id>:ref:…`),
  ne `repo:owner/repo:ref:…`. Kdyby ses identitu někdy zakládal ručně, nejdřív
  zjisti, jaký subject GitHub pro repo skutečně vystavuje, jinak se přihlášení
  nepovede (`AADSTS70021`).
- Starý secret `AZURE_WEBAPP_PUBLISH_PROFILE` už se nepoužívá a obsahuje
  přihlašovací údaje k nasazení, smaž ho.

### Proč ne Azure Container Apps

Původně jsme běželi na Container Apps (Docker image), ale `az containerapp
up` si u toho **automaticky založí Azure Container Registry (Basic SKU)**,
a ten na rozdíl od Container Apps samotných **nemá žádnou free tier
variantu** — účtuje se paušálně bez ohledu na využití (~€0.66/měsíc,
zjištěno přes Cost Management). Container App sama o sobě stála skoro nic
(škáluje na 0 instancí, když nic neděláš), ale registr tikal pořád.

Řešení: App Service umí Python nativně bez kontejneru vůbec, takže odpadá
potřeba jakéhokoli registru. Container App + jeho prostředí + Log
Analytics workspace jsme smazali (registr smazán jako první, což na pár
minut backend fakticky vyřadilo z provozu, než jsme přešli na App
Service — bacha na pořadí, kdyby se tohle dělalo znovu).

## Co tu (zatím) není

- Silnější ověření appky (App Attest / Play Integrity) — dnešní `X-App-Key`
  + `X-Device-Id` je jen lehká obrana, viz „Auth a kvóty“ výš.
- Vazba kvóty na platící uživatele (předplatné) — dnes je kvóta jen na
  zařízení, ne na účet.
