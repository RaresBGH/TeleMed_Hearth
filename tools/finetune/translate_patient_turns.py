"""
Stage 3 (simplified): Translate 80 English medical patient turns to Romanian.
Single Gemini call per row, no thinking, no rewriting. Output used as variety
seeds for Step 9 synthetic dialogue generation — NOT direct training data.
"""

import json
import os
import sys
import time
import traceback
from pathlib import Path

from dotenv import load_dotenv
from google import genai
from google.genai import types
from google.genai import errors as genai_errors

load_dotenv()

MODEL_NAME = "gemini-3-flash-preview"
INPUT_PATH  = Path("/home/corb_d/sovereign-factory/datasets/medical/processed/medical_chatbot_en.jsonl")
OUTPUT_PATH = Path("/home/corb_d/sovereign-factory/datasets/medical/processed/medical_patient_turns_ro.jsonl")
TARGET_ROWS = 80
SLEEP_BETWEEN_CALLS = 24  # 5 RPM free tier; 24 s ≈ 2.5 calls/min

SYSTEM_PROMPT = (
    "You are a faithful translator from English to Romanian, specialized in medical "
    "conversational text. Translate the patient's symptom description to Romanian keeping "
    "the same meaning, tone, and level of detail. Use Romanian medical terminology where "
    "appropriate. Preserve emotional register (worry, urgency, casualness). Output ONLY "
    "the translated text, no commentary, no quotes around the output, no markdown."
)


# ---------- API call ----------

def translate(client: genai.Client, text: str) -> tuple[str, int, int]:
    """Return (translated_text, input_tokens, output_tokens)."""
    response = client.models.generate_content(
        model=MODEL_NAME,
        contents=text,
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            temperature=0.3,
            max_output_tokens=1024,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        ),
    )
    translated = (response.text or "").strip().strip('"').strip("“").strip("”").strip("'")
    in_tok  = response.usage_metadata.prompt_token_count or 0
    out_tok = response.usage_metadata.candidates_token_count or 0
    return translated, in_tok, out_tok


def _translate_with_retry(client: genai.Client, text: str) -> tuple[str | None, int, int, str | None]:
    """
    Returns (translated, in_tok, out_tok, error_msg).
    translated is None on non-retryable 4xx; error_msg is None on success.
    """
    max_retries = 3
    backoff_5xx = [5, 15, 45]

    for attempt in range(max_retries):
        try:
            translated, in_tok, out_tok = translate(client, text)
            return translated, in_tok, out_tok, None

        except genai_errors.ClientError as e:
            msg = str(e)
            code = getattr(e, "status_code", None) or getattr(e, "code", 0)

            if "RESOURCE_EXHAUSTED" in msg or code == 429:
                # Try to parse retryDelay from error body
                import re
                delay_match = re.search(r"retryDelay['\"]?\s*[:=]\s*['\"]?(\d+)", msg)
                sleep_sec = int(delay_match.group(1)) + 5 if delay_match else 60
                print(f"  429 rate-limited. Sleeping {sleep_sec}s (attempt {attempt+1}/{max_retries})...")
                time.sleep(sleep_sec)
                continue  # retry same row

            # Other 4xx — non-retryable
            print(f"  4xx error: {msg[:200]}")
            return None, 0, 0, msg[:300]

        except genai_errors.ServerError as e:
            if attempt < max_retries - 1:
                sleep_sec = backoff_5xx[attempt]
                print(f"  5xx error. Sleeping {sleep_sec}s (attempt {attempt+1}/{max_retries})...")
                time.sleep(sleep_sec)
                continue
            return None, 0, 0, str(e)[:300]

    return None, 0, 0, "Max retries exceeded"


# ---------- Main ----------

def main() -> None:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("ERROR: GEMINI_API_KEY is not set. Add it to tools/finetune/.env.")
        sys.exit(1)

    if not INPUT_PATH.exists():
        print(f"ERROR: Input file not found: {INPUT_PATH}")
        sys.exit(1)

    client = genai.Client(api_key=api_key)

    # Idempotency / resume
    skip = 0
    if OUTPUT_PATH.exists():
        with OUTPUT_PATH.open(encoding="utf-8") as f:
            existing = sum(1 for line in f if line.strip())
        if existing >= TARGET_ROWS:
            print(f"Output file already complete ({existing} rows). Delete it to re-run.")
            sys.exit(0)
        skip = existing
        print(f"Resuming from row {skip + 1} ({existing} rows already written).")

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    # Read input rows (skip already-done, take up to TARGET_ROWS total)
    need = TARGET_ROWS - skip
    input_rows: list[dict] = []
    with INPUT_PATH.open(encoding="utf-8") as f:
        for i, line in enumerate(f):
            line = line.strip()
            if not line:
                continue
            if i < skip:
                continue
            input_rows.append(json.loads(line))
            if len(input_rows) >= need:
                break

    wall_start  = time.time()
    total_in    = 0
    total_out   = 0
    total_errors = 0

    out_handle = OUTPUT_PATH.open("a", encoding="utf-8")
    try:
        for i, row in enumerate(input_rows):
            abs_idx  = skip + i + 1
            source_id = row.get("source_id", f"row-{abs_idx}")
            en_text   = row["messages"][0]["content"]

            print(f"[{abs_idx}/{TARGET_ROWS}] source_id={source_id} | translating...")

            translated, in_tok, out_tok, err = _translate_with_retry(client, en_text)

            if translated is not None:
                out_row = {
                    "source_id":  source_id,
                    "patient_en": en_text,
                    "patient_ro": translated,
                }
                total_in  += in_tok
                total_out += out_tok
                print(f"[{abs_idx}/{TARGET_ROWS}] OK | tokens: {in_tok}+{out_tok}")
            else:
                out_row = {
                    "source_id":  source_id,
                    "patient_en": en_text,
                    "patient_ro": None,
                    "error":      err,
                }
                total_errors += 1
                print(f"[{abs_idx}/{TARGET_ROWS}] ERROR: {err}")

            out_handle.write(json.dumps(out_row, ensure_ascii=False) + "\n")
            out_handle.flush()

            if i < len(input_rows) - 1:
                time.sleep(SLEEP_BETWEEN_CALLS)

    finally:
        out_handle.close()

    wall_sec = time.time() - wall_start
    print(f"\n{'='*50}")
    print(f"Done. Rows processed: {len(input_rows)} | Errors: {total_errors}")
    print(f"Total tokens — input: {total_in} | output: {total_out}")
    print(f"Wall clock: {wall_sec:.1f}s ({wall_sec/60:.1f} min)")
    print(f"Output: {OUTPUT_PATH}")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
