import os
from typing import Literal, Optional

from anthropic import Anthropic
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

load_dotenv()

MODEL = os.environ.get("LIVRESCAN_MODEL", "claude-haiku-4-5-20251001")
MAX_TEXT_LENGTH = 8000
MAX_ITEMS_CAP = 30

app = FastAPI(title="LivreScan backend")
client = Anthropic()  # reads ANTHROPIC_API_KEY from the environment


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


EXTRACT_TOOL = {
    "name": "return_vocabulary",
    "description": "Return the extracted vocabulary/phrase candidates for a language learner.",
    "input_schema": {
        "type": "object",
        "properties": {
            "items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "original": {
                            "type": "string",
                            "description": "The word or phrase exactly as it appears in the source text",
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
    },
}


def build_prompt(text: str, source_lang: str, target_lang: str, max_items: int) -> str:
    return (
        "You are helping a language learner build flashcards from a scanned book page.\n"
        f"Source language: {source_lang}. Target (translation) language: {target_lang}.\n"
        f"From the OCR text below (it may contain OCR noise/errors -- ignore garbage), "
        f"pick up to {max_items} of the most useful words and phrases for a learner to study: "
        "prioritize words/idioms that are common enough to be worth learning but not trivially "
        "basic, and multi-word phrases/idioms that don't translate literally. Skip proper nouns, "
        "numbers, and OCR garbage.\n"
        f"For each item give: the exact original form, a natural translation into {target_lang}, "
        "whether it's a 'word' or 'phrase', its part of speech (for words), an example sentence "
        "(reuse one from the text if a good one exists, otherwise write a short natural one), and "
        "an estimated CEFR difficulty (A1-C2).\n\n"
        f"Text:\n{text}"
    )


@app.post("/extract", response_model=ExtractResponse)
def extract(req: ExtractRequest) -> ExtractResponse:
    text = req.text.strip()
    if not text:
        raise HTTPException(400, "text must not be empty")
    text = text[:MAX_TEXT_LENGTH]

    max_items = max(1, min(req.maxItems, MAX_ITEMS_CAP))
    prompt = build_prompt(text, req.sourceLang, req.targetLang, max_items)

    message = client.messages.create(
        model=MODEL,
        max_tokens=4096,
        tools=[EXTRACT_TOOL],
        tool_choice={"type": "tool", "name": "return_vocabulary"},
        messages=[{"role": "user", "content": prompt}],
    )

    for block in message.content:
        if block.type == "tool_use" and block.name == "return_vocabulary":
            return ExtractResponse(items=block.input.get("items", []))

    raise HTTPException(502, "model did not return structured vocabulary")


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
