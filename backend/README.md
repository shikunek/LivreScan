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

- Autentizace / rate limiting — pro lokální vývoj nepotřeba, před nasazením
  do produkce přidat (např. API klíč appky + limit requestů na zařízení).
