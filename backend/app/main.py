import json
import os
import re
from functools import lru_cache
from typing import Literal, Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

load_dotenv()

MAX_TEXT_LENGTH = 8000
MAX_ITEMS_CAP = 30

# Which extraction backend to use: "mock" (free, fake data), "claude"
# (Anthropic, paid), or "openrouter" (free-tier hosted Phi-4, no cost).
PROVIDER = os.environ.get("LIVRESCAN_PROVIDER", "mock").lower()

CLAUDE_MODEL = os.environ.get("LIVRESCAN_MODEL", "claude-haiku-4-5-20251001")
OPENROUTER_MODEL = os.environ.get(
    "LIVRESCAN_OPENROUTER_MODEL", "nex-agi/nex-n2.5-pro:free"
)
GROQ_MODEL = os.environ.get("LIVRESCAN_GROQ_MODEL", "openai/gpt-oss-120b")

app = FastAPI(title="LivreScan backend")


class ExtractRequest(BaseModel):
    text: str
    sourceLang: str
    targetLang: str
    maxItems: int = 15


class VocabItem(BaseModel):
    original: str
    translation: str
    type: Literal["word", "phrase"]
    partOfSpeech: Optional[str] = None
    exampleSentence: str
    difficulty: Optional[str] = None


class ExtractResponse(BaseModel):
    items: list[VocabItem]


VOCAB_SCHEMA = {
    "type": "object",
    "properties": {
        "items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "original": {
                        "type": "string",
                        "description": (
                            "The dictionary form of ONE learnable unit: a verb in the "
                            "infinitive, a noun with its article, an adjective in its base "
                            "form, or a fixed multi-word expression. Not a free-form chunk "
                            "of the sentence."
                        ),
                    },
                    "translation": {"type": "string"},
                    "type": {"type": "string", "enum": ["word", "phrase"]},
                    "partOfSpeech": {"type": "string"},
                    "exampleSentence": {
                        "type": "string",
                        "description": "A sentence using the word/phrase, ideally reused from the source text",
                    },
                    "difficulty": {
                        "type": "string",
                        "enum": ["A1", "A2", "B1", "B2", "C1", "C2"],
                    },
                },
                "required": ["original", "translation", "type", "exampleSentence"],
            },
        }
    },
    "required": ["items"],
}


def build_prompt(text: str, source_lang: str, target_lang: str, max_items: int) -> str:
    return (
        "You are helping a language learner build flashcards from a scanned book page.\n"
        f"Source language: {source_lang}. Target (translation) language: {target_lang}.\n"
        f"From the OCR text below (it may contain OCR noise/errors -- ignore garbage), "
        f"pick up to {max_items} of the most useful items for a learner to study: "
        "common enough to be worth learning but not trivially basic. Skip proper nouns, "
        "numbers, and OCR garbage.\n\n"
        "Split the text into SMALL learnable units. One flashcard = one unit, never a whole "
        "clause or a free combination of words. Take the words apart, for example (French): "
        "'regardait par la fenetre' becomes two cards, 'regarder' and 'la fenetre' -- not "
        "one card with the whole chunk.\n"
        "Write every item in its DICTIONARY FORM, not as it is printed in the text:\n"
        "- Verbs: the infinitive ('regardait' -> 'regarder', 'nous sommes alles' -> 'aller'; "
        "keep reflexive pronouns: 'se souvenir').\n"
        "- Nouns: always WITH their article, so the gender is learned with the word "
        "('la fenetre', 'le livre', 'un arbre'; in German 'der/die/das', in Spanish 'el/la', "
        "etc.). ALWAYS the singular, even when the text has a plural ('les enfants' -> "
        "'un enfant', 'des livres' -> 'un livre'). If the definite article would be elided "
        "(French l'), use the indefinite article instead ('un arbre') so the gender stays "
        "visible. For languages without articles just give the noun in its base form.\n"
        "- Adjectives: the base form (French masculine singular: 'grande' -> 'grand'). "
        "Other words (adverbs, prepositions, conjunctions): as they are.\n"
        "Keep words together ONLY when they form a fixed expression or idiom whose meaning "
        "is not obvious from the single words. Such an expression is ONE card, never split "
        "into its parts (French: 'il pleuvait a verse' -> the single phrase 'pleuvoir a "
        "verse', not 'pleuvoir' + 'a verse'; 'avoir besoin de'; 'il y a'). Those get type "
        "'phrase', in their base form (infinitive for verbs). Ordinary combinations such as "
        "verb + preposition + noun ('regardait par la fenetre') are NOT fixed expressions: "
        "split them. Everything else is type 'word' (a noun with its article still counts as "
        "one 'word'). Give each dictionary form only once, even if it appears several "
        "times.\n\n"
        f"For each item give: the dictionary form as described above, a natural translation "
        f"into {target_lang} (also in its dictionary form: infinitive, singular; add the article "
        "only if the target language uses them), 'word' or 'phrase', the part of speech, an "
        "example sentence (reuse the sentence from the text where the item occurs -- it may "
        "contain the inflected form -- otherwise write a short natural one), and an "
        "estimated CEFR difficulty (A1-C2).\n\n"
        f"Text:\n{text}"
    )


def mock_extract(text: str, max_items: int, **_ignored) -> list[VocabItem]:
    """Fake but structurally valid extraction, so the app can be exercised
    end-to-end without spending real API credits."""
    words = re.findall(r"[^\W\d_]+", text, flags=re.UNICODE)
    seen: list[str] = []
    for word in words:
        lower = word.lower()
        if len(word) >= 4 and lower not in seen:
            seen.append(lower)
        if len(seen) >= max_items:
            break

    items = []
    for i, word in enumerate(seen):
        is_phrase = i % 3 == 0
        items.append(
            VocabItem(
                original=word,
                translation=f"[MOCK] {word}",
                type="phrase" if is_phrase else "word",
                partOfSpeech=None if is_phrase else "mock",
                exampleSentence=text[:120].strip(),
                difficulty="B1",
            )
        )
    return items


@lru_cache
def _anthropic_client():
    from anthropic import Anthropic

    return Anthropic()  # reads ANTHROPIC_API_KEY from the environment


def claude_extract(*, prompt: str, **_ignored) -> list[VocabItem]:
    tool = {
        "name": "return_vocabulary",
        "description": "Return the extracted vocabulary/phrase candidates for a language learner.",
        "input_schema": VOCAB_SCHEMA,
    }
    message = _anthropic_client().messages.create(
        model=CLAUDE_MODEL,
        max_tokens=4096,
        tools=[tool],
        tool_choice={"type": "tool", "name": "return_vocabulary"},
        messages=[{"role": "user", "content": prompt}],
    )
    for block in message.content:
        if block.type == "tool_use" and block.name == "return_vocabulary":
            return [VocabItem(**item) for item in block.input.get("items", [])]
    raise HTTPException(502, "Claude did not return structured vocabulary")


@lru_cache
def _openrouter_client():
    from openai import OpenAI

    return OpenAI(
        base_url="https://openrouter.ai/api/v1",
        api_key=os.environ.get("OPENROUTER_API_KEY", ""),
    )


def _extract_json_object(raw: str) -> dict:
    """Reasoning models often wrap JSON in prose or ```json fences; pull out
    the first top-level {...} object instead of assuming raw is pure JSON."""
    text = raw.strip()
    if text.startswith("```"):
        text = text.strip("`")
        if text.lower().startswith("json"):
            text = text[4:]
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1:
        raise HTTPException(502, "OpenRouter model did not return JSON")
    return json.loads(text[start : end + 1])


def openrouter_extract(*, prompt: str, **_ignored) -> list[VocabItem]:
    schema_hint = json.dumps(VOCAB_SCHEMA)
    full_prompt = (
        f"{prompt}\n\n"
        "Respond with ONLY a single JSON object matching this JSON schema, "
        f"no other text, no markdown fences:\n{schema_hint}"
    )
    completion = _openrouter_client().chat.completions.create(
        model=OPENROUTER_MODEL,
        messages=[{"role": "user", "content": full_prompt}],
    )
    raw = completion.choices[0].message.content or ""
    data = _extract_json_object(raw)
    return [VocabItem(**item) for item in data.get("items", [])]


@lru_cache
def _groq_client():
    from openai import OpenAI

    return OpenAI(
        base_url="https://api.groq.com/openai/v1",
        api_key=os.environ.get("GROQ_API_KEY", ""),
    )


def groq_extract(*, prompt: str, **_ignored) -> list[VocabItem]:
    tool = {
        "type": "function",
        "function": {
            "name": "return_vocabulary",
            "description": "Return the extracted vocabulary/phrase candidates for a language learner.",
            "parameters": VOCAB_SCHEMA,
        },
    }
    completion = _groq_client().chat.completions.create(
        model=GROQ_MODEL,
        messages=[{"role": "user", "content": prompt}],
        tools=[tool],
        tool_choice={"type": "function", "function": {"name": "return_vocabulary"}},
    )
    tool_calls = completion.choices[0].message.tool_calls
    if not tool_calls:
        raise HTTPException(502, "Groq did not return structured vocabulary")
    args = json.loads(tool_calls[0].function.arguments)
    return [VocabItem(**item) for item in args.get("items", [])]


EXTRACTORS = {
    "mock": mock_extract,
    "claude": claude_extract,
    "openrouter": openrouter_extract,
    "groq": groq_extract,
}


@app.post("/extract", response_model=ExtractResponse)
def extract(req: ExtractRequest) -> ExtractResponse:
    text = req.text.strip()
    if not text:
        raise HTTPException(400, "text must not be empty")
    text = text[:MAX_TEXT_LENGTH]

    max_items = max(1, min(req.maxItems, MAX_ITEMS_CAP))
    prompt = build_prompt(text, req.sourceLang, req.targetLang, max_items)

    extractor = EXTRACTORS.get(PROVIDER)
    if extractor is None:
        raise HTTPException(500, f"Unknown LIVRESCAN_PROVIDER: {PROVIDER!r}")

    items = extractor(text=text, max_items=max_items, prompt=prompt)
    return ExtractResponse(items=items)


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "provider": PROVIDER}
