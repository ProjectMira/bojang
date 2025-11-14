import torch
import soundfile as sf
from transformers import AutoTokenizer, AutoModelForTextToWaveform

# 1. Load Tibetan MMS TTS model (Central Tibetan: "bod")
MODEL_NAME = "facebook/mms-tts-bod"

print("Loading model and tokenizer...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
model = AutoModelForTextToWaveform.from_pretrained(MODEL_NAME)

# Use GPU if available
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model.to(device)


def tibetan_text_to_speech(text: str, out_path: str = "tibetan_tts.wav", sample_rate: int = 16000):
    """
    Convert Tibetan text (Unicode) to audio and save as a WAV file.

    Args:
        text: Tibetan text, e.g. 'བོད་ཡིག་ནང་བསྐུར།'
        out_path: output WAV filename
        sample_rate: output sampling rate (Hz)
    """

    # 2. Tokenize text
    inputs = tokenizer(text, return_tensors="pt")

    # Move tensors to the same device as the model
    inputs = {k: v.to(device) for k, v in inputs.items()}

    # 3. Generate waveform with the TTS model
    with torch.no_grad():
        output = model(**inputs).waveform

    # waveform shape: (batch, samples)
    # Convert to CPU numpy array
    audio = output.squeeze().cpu().numpy()

    # 4. Save audio to file
    sf.write(out_path, audio, sample_rate)

    print(f"Saved Tibetan TTS audio to: {out_path}")

# --------- CONFIG ---------
LEVELS_JSON = "assets/quiz_data/levels.json"
AUDIO_ROOT = "assets/facebook_audios"          # will create assets/audios/level-1, level-2, ...
MODEL_NAME = "facebook/mms-tts-bod"   # MMS Tibetan TTS (Central Tibetan)
# --------------------------
import json
import os
from pathlib import Path
import re



# Tibetan Unicode range: U+0F00–U+0FFF
TIBETAN_RE = re.compile(r"[\u0F00-\u0FFF]+")


def extract_tibetan_from_vocab_item(item: str) -> str:
    """
    metadata.vocabularyIntroduced entries look like 'ཀ(ka)'.
    This extracts only the Tibetan part (before the ( or from Unicode range).
    """
    # First try: everything before '('
    before_paren = item.split("(")[0].strip()
    if before_paren:
        return before_paren

    # Fallback: regex for Tibetan chars
    match = TIBETAN_RE.search(item)
    return match.group(0) if match else ""



def extract_tibetan_strings_from_file(json_path: str):
    """
    Yield all Tibetan strings from a single quiz JSON file.
    Looks at:
      - exercises[*].tibetanText
      - metadata.vocabularyIntroduced[*]
    """
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # 1) From exercises[].tibetanText
    for ex in data.get("exercises", []):
        tib = ex.get("tibetanText")
        if isinstance(tib, str) and tib.strip():
            yield tib.strip()

    # 2) From metadata.vocabularyIntroduced[]
    meta = data.get("metadata", {})
    vocab_list = meta.get("vocabularyIntroduced", [])
    for item in vocab_list:
        if isinstance(item, str):
            tib = extract_tibetan_from_vocab_item(item)
            if tib:
                yield tib

def main():
    # Load levels.json
    with open(LEVELS_JSON, "r", encoding="utf-8") as f:
        levels_data = json.load(f)

    all_levels = levels_data.get("levels", [])

    for level_block in all_levels:
        level_num = level_block.get("level")  # 1,2,3
        sublevels = level_block.get("sublevels", [])

        print(f"\n=== Processing Level {level_num} ===")

        for sub in sublevels:
            sub_level_code = sub.get("level")      # e.g. "1.1"
            sub_path = sub.get("path")             # e.g. assets/quiz_data/level-1/alphabet.json
            sub_type = sub.get("type", "text")     # default to "text" if missing

            # Skip non-text-only sublevels if you want
            if sub_type in ("image",):  # you can also skip "audio" or "mixed" if desired
                print(f"[SKIP] {sub_level_code} ({sub_type}) → {sub_path}")
                continue

            print(f"[SUBLEVEL] {sub_level_code} → {sub_path}")

            # Collect unique Tibetan strings
            json_path = Path(sub_path)
            if not json_path.exists():
                print(f"  [WARN] File not found: {json_path}")
                continue

            tibetan_strings = list(set(extract_tibetan_strings_from_file(str(json_path))))
            tibetan_strings.sort()

            if not tibetan_strings:
                print("  [INFO] No Tibetan text found.")
                continue

            # Output folder: assets/audios/level-1/
            level_dir_name = json_path.parent.name   # "level-1"
            out_dir = Path(AUDIO_ROOT) / level_dir_name / f"sublevel-{sub_level_code.replace('.', '-')}"
            os.makedirs(out_dir, exist_ok=True)

            # Generate an audio file per Tibetan string
            for idx, tib_text in enumerate(tibetan_strings, start=1):
                file_name = f"{sub_level_code.replace('.', '-')}_{idx:03d}.wav"
                out_path = out_dir / file_name
                tibetan_text_to_speech(tib_text, str(out_path))


if __name__ == "__main__":
    main()