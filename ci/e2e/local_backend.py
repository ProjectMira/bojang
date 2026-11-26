"""Local Bojang backend for the end-to-end suite.

Runs the FastAPI app from a bojang-backend checkout against a throwaway
SQLite file, never production:

  * firebase_admin is replaced by a stub (as functions/tests/conftest.py
    does). ID tokens are decoded without verifying their signature, which is
    what the Firebase Auth emulator issues (alg "none"), so every emulator
    account is its own learner. A token that is not a JWT maps to the
    fixed learner "e2e-learner".
  * Content is seeded from data that already exists: the conftest fixtures,
    the Basics course and dialogues written in the backend's own curriculum
    code, and the vocabulary categories in functions/bojang_local.db (an old
    local copy) when it is there. Nothing is generated.
  * Uploaded profile photos are written under <state-dir>/uploads and served
    from /e2e-uploads.

Usage (with the backend's virtualenv python):
  python ci/e2e/local_backend.py --backend <bojang-backend>/functions \
      --state-dir <dir> [--port 8787] [--vocab-db <sqlite file>]
"""
from __future__ import annotations

import argparse
import asyncio
import base64
import json
import os
import sqlite3
import sys
from pathlib import Path
from unittest.mock import MagicMock


def _args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--backend", required=True, help="bojang-backend/functions")
    p.add_argument("--state-dir", required=True)
    p.add_argument("--port", type=int, default=8787)
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--vocab-db", default=None, help="old local SQLite with vocab levels")
    return p.parse_args()


ARGS = _args()
BACKEND = Path(ARGS.backend).resolve()
STATE = Path(ARGS.state_dir).resolve()
STATE.mkdir(parents=True, exist_ok=True)
UPLOADS = STATE / "uploads"
UPLOADS.mkdir(exist_ok=True)
# tests/conftest.py names its database <tempdir>/bojang_test.sqlite3 and
# sets DATABASE_URL to it on import; point its tempdir at the state dir.
DB_PATH = STATE / "bojang_test.sqlite3"
if DB_PATH.exists():
    DB_PATH.unlink()

# Settings come from the environment only: no .env from the checkout, no
# Postgres, no credentials.
os.chdir(STATE)
os.environ.update(
    DATABASE_URL=f"sqlite+aiosqlite:///{DB_PATH}",
    DATABASE_BACKEND="sql",
    DB_AUTO_CREATE="true",
    APP_CHECK_MODE="off",
    FIREBASE_PROJECT_ID="bojang-e2e",
    FIREBASE_STORAGE_BUCKET="bojang-e2e.local",
    GOOGLE_APPLICATION_CREDENTIALS="",
)
for key in ("CRON_SECRET", "POSTHOG_API_KEY", "SENTRY_DSN"):
    os.environ.pop(key, None)
sys.path.insert(0, str(BACKEND))


# --- firebase_admin stub ---------------------------------------------------

class InvalidIdTokenError(Exception):
    pass


class ExpiredIdTokenError(Exception):
    pass


class RevokedIdTokenError(Exception):
    pass


class UserDisabledError(Exception):
    pass


def _decode(token: str, **_kw) -> dict:
    parts = token.split(".")
    if len(parts) >= 2:
        try:
            pad = "=" * (-len(parts[1]) % 4)
            claims = json.loads(base64.urlsafe_b64decode(parts[1] + pad))
            uid = claims.get("user_id") or claims.get("sub")
            if uid:
                provider = (claims.get("firebase") or {}).get("sign_in_provider")
                return {
                    **claims,
                    "uid": uid,
                    "email": claims.get("email"),
                    "name": claims.get("name"),
                    "firebase": {"sign_in_provider": provider or "anonymous"},
                }
        except Exception as exc:  # noqa: BLE001
            raise InvalidIdTokenError(str(exc)) from exc
    if token in ("", "invalid"):
        raise InvalidIdTokenError("invalid token")
    return {
        "uid": "e2e-learner",
        "email": "e2e@bojang.test",
        "name": "E2E Learner",
        "firebase": {"sign_in_provider": "password"},
    }


class _Blob:
    def __init__(self, name: str):
        self.name = name
        self.public_url = f"http://{ARGS.host}:{ARGS.port}/e2e-uploads/{name}"

    def _path(self) -> Path:
        p = UPLOADS / self.name
        p.parent.mkdir(parents=True, exist_ok=True)
        return p

    def upload_from_string(self, data, content_type=None, **_kw):
        self._path().write_bytes(data if isinstance(data, bytes) else data.encode())

    def upload_from_file(self, f, content_type=None, **_kw):
        self._path().write_bytes(f.read())

    def make_public(self):
        return None

    def delete(self):
        p = UPLOADS / self.name
        if p.exists():
            p.unlink()

    def exists(self):
        return (UPLOADS / self.name).exists()

    def generate_signed_url(self, *a, **k):
        return self.public_url


class _Bucket:
    name = "bojang-e2e.local"

    def blob(self, name):
        return _Blob(name)


fa = MagicMock()
fa._apps = {"[DEFAULT]": MagicMock()}
fa.auth.verify_id_token = MagicMock(side_effect=_decode)
fa.auth.InvalidIdTokenError = InvalidIdTokenError
fa.auth.ExpiredIdTokenError = ExpiredIdTokenError
fa.auth.RevokedIdTokenError = RevokedIdTokenError
fa.auth.UserDisabledError = UserDisabledError
fa.auth.delete_user = MagicMock(return_value=None)
fa.storage.bucket = MagicMock(return_value=_Bucket())
fa.messaging.send = MagicMock(return_value="e2e-message")
fa.messaging.send_each = MagicMock()
for name in ("", ".credentials", ".firestore", ".auth", ".storage", ".messaging", ".app_check"):
    sys.modules["firebase_admin" + name] = getattr(fa, name[1:]) if name else fa


# --- seed ------------------------------------------------------------------

async def _seed() -> None:
    # The conftest fixtures (one unit, three words, sentences, categories).
    import tempfile

    tempfile.gettempdir = lambda: str(STATE)
    import tests.conftest as conftest  # noqa: E402  (installs its own stub)

    assert os.environ["DATABASE_URL"].endswith(str(DB_PATH)), os.environ["DATABASE_URL"]
    for name in ("", ".credentials", ".firestore", ".auth", ".storage", ".messaging", ".app_check"):
        sys.modules["firebase_admin" + name] = getattr(fa, name[1:]) if name else fa
    conftest.mock_firebase_admin.auth.verify_id_token.side_effect = _decode
    await conftest._seed_database()

    from database.engine import get_sessionmaker
    from scripts.seed_basics_course import seed_basics

    async with get_sessionmaker()() as session:
        counts = await seed_basics(session)
        await session.commit()
    print("seeded basics:", counts, flush=True)

    try:
        from services.dialogue_content import upsert_all
        from services.transliteration import botok_segmenter

        async with get_sessionmaker()() as session:
            counts = await upsert_all(session, botok_segmenter())
            await session.commit()
        print("seeded dialogues:", counts, flush=True)
    except Exception as exc:  # noqa: BLE001
        print("dialogues not seeded:", exc, flush=True)

    vocab = Path(ARGS.vocab_db) if ARGS.vocab_db else BACKEND / "bojang_local.db"
    if vocab.exists():
        await _copy_vocab(vocab)
    await _media_fixtures()


async def _copy_vocab(path: Path) -> None:
    """Vocabulary levels (Animals, Fruits, ...) from an old local SQLite."""
    from sqlalchemy import select

    from database.engine import get_sessionmaker
    from database.sql_models import LevelORM, LexemeORM, TranslationORM, UnitORM
    from firebase_config import get_settings

    src = sqlite3.connect(path)
    src.row_factory = sqlite3.Row
    async with get_sessionmaker()() as session:
        for u in src.execute("select * from units"):
            if await session.get(UnitORM, u["id"]) is None:
                session.add(UnitORM(
                    id=u["id"], course_id=get_settings().default_course_code,
                    title=u["title"], description=u["description"],
                    sort_order=u["sort_order"] or 100,
                ))
        await session.flush()
        existing = set((await session.execute(select(LevelORM.id))).scalars())
        for lv in src.execute("select * from levels"):
            if lv["id"] in existing:
                continue
            session.add(LevelORM(
                id=lv["id"], unit_id=lv["unit_id"], code=lv["code"], title=lv["title"],
                description=lv["description"], sort_order=lv["sort_order"] or 0,
                required_xp=lv["required_xp"] or 0,
                tags=json.loads(lv["tags"]) if lv["tags"] else [],
                word_count=lv["word_count"] or 0, sentence_count=lv["sentence_count"] or 0,
            ))
        await session.flush()
        lex_ids = set((await session.execute(select(LexemeORM.id))).scalars())
        n = 0
        for x in src.execute("select * from lexemes"):
            if x["id"] in lex_ids:
                continue
            session.add(LexemeORM(
                id=x["id"], language_code=x["language_code"] or "bo", level_id=x["level_id"],
                lemma=x["lemma"], transliteration=x["transliteration"],
                part_of_speech=x["part_of_speech"],
                tags=json.loads(x["tags"]) if x["tags"] else [],
                difficulty_rank=x["difficulty_rank"] or 1,
            ))
            n += 1
        await session.flush()
        tr_ids = set((await session.execute(select(TranslationORM.id))).scalars())
        for t in src.execute("select * from translations"):
            if t["id"] in tr_ids:
                continue
            session.add(TranslationORM(
                id=t["id"], lexeme_id=t["lexeme_id"], language_code=t["language_code"] or "en",
                text=t["text"], notes=t["notes"],
            ))
        await session.commit()
    print(f"copied {n} vocabulary words from {path}", flush=True)


def _png(rgb: tuple[int, int, int], size: int = 64) -> bytes:
    """A solid-colour PNG (test fixture, not content)."""
    import struct
    import zlib

    raw = b"".join(b"\x00" + bytes(rgb) * size for _ in range(size))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def _silent_wav(ms: int = 300) -> bytes:
    import struct

    rate, n = 8000, 8000 * ms // 1000
    data = b"\x80" * n
    return (b"RIFF" + struct.pack("<I", 36 + n) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 1, 1, rate, rate, 1, 8)
            + b"data" + struct.pack("<I", n) + data)


MEDIA_LEVELS = ("vocab-animals", "vocab-fruits", "vocab-colors", "vocab-family")


async def _media_fixtures() -> None:
    """Pictures and (silent) audio for a few topics, served locally, so the
    picture and listening games have something to play with."""
    from sqlalchemy import select

    from database.engine import get_sessionmaker
    from database.sql_models import LexemeORM

    media = UPLOADS / "e2e-media"
    media.mkdir(parents=True, exist_ok=True)
    (media / "silence.wav").write_bytes(_silent_wav())
    base = f"http://{ARGS.host}:{ARGS.port}/e2e-uploads/e2e-media"
    palette = [(231, 76, 60), (46, 204, 113), (52, 152, 219), (241, 196, 15), (155, 89, 182), (230, 126, 34)]
    n = 0
    async with get_sessionmaker()() as session:
        rows = (await session.execute(select(LexemeORM))).scalars().all()
        for i, lex in enumerate(rows):
            if not lex.audio_url:
                lex.audio_url = f"{base}/silence.wav"
            if lex.level_id in MEDIA_LEVELS and not lex.image_url:
                name = f"pic-{i}.png"
                (media / name).write_bytes(_png(palette[i % len(palette)]))
                lex.image_url = f"{base}/{name}"
                n += 1
        await session.commit()
    print(f"media fixtures: {n} pictures, silent audio for every word", flush=True)


RIVALS = [("e2e-rival-1", "Rival One", 400), ("e2e-rival-2", "Rival Two", 250), ("e2e-rival-3", "Rival Three", 90)] + [
    (f"e2e-rival-{i}", f"Learner {i:02d}", 80 - i) for i in range(4, 28)
]


def _token(uid: str) -> str:
    claims = {"user_id": uid, "sub": uid, "firebase": {"sign_in_provider": "anonymous"}}
    body = base64.urlsafe_b64encode(json.dumps(claims).encode()).decode().rstrip("=")
    return f"eyJhbGciOiJub25lIn0.{body}."


def _seed_rivals(app) -> None:
    """Three other learners with XP this week, so the board has rows."""
    from fastapi.testclient import TestClient
    from sqlalchemy import select

    from database.engine import get_sessionmaker
    from database.sql_models import AuthIdentityORM, XPEventORM
    from firebase_config import get_settings

    with TestClient(app) as client:
        for uid, name, _ in RIVALS:
            h = {"Authorization": f"Bearer {_token(uid)}"}
            r = client.post("/auth/sync", headers=h, json={"email": f"{uid}@bojang.test", "display_name": name})
            r.raise_for_status()
            client.patch("/auth/me", headers=h, json={"display_name": name})

    async def xp() -> None:
        async with get_sessionmaker()() as session:
            for uid, _, amount in RIVALS:
                ident = (await session.execute(
                    select(AuthIdentityORM).where(AuthIdentityORM.provider_user_id == uid)
                )).scalar_one()
                session.add(XPEventORM(
                    user_id=ident.user_id, course_id=get_settings().default_course_code,
                    source_type="e2e_seed", xp_delta=amount,
                ))
            await session.commit()

    asyncio.run(xp())
    print("seeded rivals:", [r[1] for r in RIVALS], flush=True)


def main() -> None:
    import uvicorn
    from fastapi.staticfiles import StaticFiles

    asyncio.run(_seed())

    from main import app

    app.mount("/e2e-uploads", StaticFiles(directory=str(UPLOADS)), name="e2e-uploads")

    @app.get("/e2e/health")
    async def _e2e_health():
        return {"ok": True, "db": str(DB_PATH)}

    # --- test-only helpers (this file never runs in production) ---
    # Outage per learner (Firebase uid), so parallel runs don't see it;
    # uid "*" takes the whole server down.
    outage: set[str] = set()

    @app.middleware("http")
    async def _outage(request, call_next):
        from fastapi.responses import JSONResponse

        if outage and not request.url.path.startswith("/e2e"):
            uid = None
            auth = request.headers.get("authorization", "")
            if auth.lower().startswith("bearer "):
                try:
                    uid = _decode(auth.split()[1])["uid"]
                except Exception:  # noqa: BLE001
                    uid = None
            if "*" in outage or (uid and uid in outage):
                return JSONResponse({"detail": "e2e outage"}, status_code=503)
        return await call_next(request)

    @app.post("/e2e/outage")
    async def _set_outage(body: dict):
        """{"uid": <firebase uid or "*">, "on": bool}"""
        uid = body.get("uid") or "*"
        (outage.add if body.get("on") else outage.discard)(uid)
        return {"outage": sorted(outage)}

    @app.post("/e2e/xp")
    async def _grant_xp(body: dict):
        """Gives a learner (by Firebase uid) XP this week."""
        from sqlalchemy import select

        from database.engine import get_sessionmaker
        from database.sql_models import AuthIdentityORM, XPEventORM
        from firebase_config import get_settings

        async with get_sessionmaker()() as session:
            ident = (await session.execute(
                select(AuthIdentityORM).where(AuthIdentityORM.provider_user_id == body["uid"])
            )).scalar_one_or_none()
            if ident is None:
                return {"ok": False, "error": "no such learner (call auth/sync first)"}
            session.add(XPEventORM(
                user_id=ident.user_id, course_id=get_settings().default_course_code,
                source_type="e2e_seed", xp_delta=int(body.get("xp", 10)),
            ))
            await session.commit()
        return {"ok": True}

    _seed_rivals(app)
    print(f"E2E backend on http://{ARGS.host}:{ARGS.port} (db {DB_PATH})", flush=True)
    uvicorn.run(app, host=ARGS.host, port=ARGS.port, log_level="warning")


if __name__ == "__main__":
    main()
