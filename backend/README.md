# LivreScan backend

Malá FastAPI služba s jedním endpointem `POST /extract`. Přijme OCR text
z appky, zavolá Claude a vrátí seznam slovíček/frází s překladem — appka
sama žádný Anthropic klíč nemá, ten zůstává jen tady na serveru.

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

Text extrakce jede přes Anthropic tool-use (vynucené strukturované volání
nástroje), takže odpověď je vždy validní JSON podle schématu, ne volný text
k parsování.

Model je `claude-haiku-4-5-20251001` (rychlý a levný, pro tenhle úkol
dostatečný) — jde přepsat proměnnou prostředí `LIVRESCAN_MODEL`.

## Proč ne Gemini

Zkoušeli jsme nejdřív Gemini free tier, ale Google je (od poloviny 2026)
uprostřed přechodu na nový formát API klíčů (`AQ.Ab...` místo `AIzaSy...`)
a nový formát je aktuálně rozbitý — volání skončí na `401
ACCESS_TOKEN_TYPE_UNSUPPORTED` / `API_KEY_SERVICE_BLOCKED` i po povolení
API v Google Cloud Console. Je to široce hlášený problém na straně Googlu,
ne něco opravitelného v tomhle repu. Až to Google opraví, přechod zpět by
byl jednoduchý (kontrakt `/extract` je nezávislý na tom, co běží uvnitř).

## Co tu (zatím) není

- Autentizace / rate limiting — pro lokální vývoj nepotřeba, před nasazením
  do produkce přidat (např. API klíč appky + limit requestů na zařízení).
- Nasazení — funguje jako běžná ASGI appka, jde hostit kdekoli (Fly.io,
  Render, Railway, Cloud Run...) příkazem
  `uvicorn app.main:app --host 0.0.0.0 --port $PORT`.
