#!/usr/bin/env python3
"""Make Bojang's feedback sounds (see lib/services/feedback.dart).

Every sound here is original: synthesised from sine and triangle waves with
the Python standard library, or pitch-stepped from the app's own
assets/audio/correct.mp3. Nothing is sampled from anywhere else.

Run from the app root:

    python3 tool/sounds/make_sounds.py

Needs ffmpeg with libmp3lame on PATH (brew install ffmpeg). Writes WAVs to
tool/sounds/build/ (not committed) and MP3s to assets/audio/.
"""

from __future__ import annotations

import math
import os
import random
import struct
import subprocess
import sys
import wave

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
BUILD = os.path.join(HERE, "build")
OUT = os.path.join(ROOT, "assets", "audio")

# Equal-tempered note frequencies used below (A4 = 440 Hz).
NOTE = {
    "C5": 523.25, "D5": 587.33, "E5": 659.26, "G5": 783.99, "A5": 880.00,
    "C6": 1046.50, "D6": 1174.66, "E6": 1318.51, "F#6": 1479.98,
    "G6": 1567.98, "A6": 1760.00, "C7": 2093.00,
}


def silence(seconds: float) -> list[float]:
    return [0.0] * int(RATE * seconds)


def mix_into(track: list[float], clip: list[float], at: float, gain: float = 1.0) -> None:
    start = int(RATE * at)
    need = start + len(clip)
    if need > len(track):
        track.extend([0.0] * (need - len(track)))
    for i, v in enumerate(clip):
        track[start + i] += v * gain


def triangle(phase: float) -> float:
    """Triangle wave in -1..1 for a phase in cycles."""
    p = phase % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


def bell(freq: float, seconds: float, decay: float = 6.0, bright: float = 0.25) -> list[float]:
    """A soft mallet/bell: sine fundamental, a quiet octave and a faint
    inharmonic partial, 4 ms attack, exponential decay."""
    n = int(RATE * seconds)
    out = []
    attack = int(RATE * 0.004)
    for i in range(n):
        t = i / RATE
        env = math.exp(-decay * t) * (min(1.0, i / attack) if attack else 1.0)
        v = math.sin(2 * math.pi * freq * t)
        v += bright * math.sin(2 * math.pi * freq * 2 * t) * math.exp(-decay * 1.8 * t)
        v += 0.08 * math.sin(2 * math.pi * freq * 2.76 * t) * math.exp(-decay * 3 * t)
        out.append(v * env)
    return out


def pad(freqs: list[float], seconds: float, fade_in: float = 0.05) -> list[float]:
    """A soft triangle chord that swells in and fades out, with a gentle
    tremolo so it does not sound static."""
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / fade_in) * (1 - t / seconds) ** 2
        trem = 1 - 0.12 * (0.5 + 0.5 * math.sin(2 * math.pi * 5.5 * t))
        v = sum(triangle(f * t) for f in freqs) / len(freqs)
        out.append(v * env * trem)
    return out


def pluck(freq: float, seconds: float, glide: float = 0.0) -> list[float]:
    """A very short sine pluck for taps; [glide] bends the pitch up."""
    n = int(RATE * seconds)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq * (1 + glide * t / seconds)
        phase += f / RATE
        env = math.exp(-t * 9 / seconds) * min(1.0, i / (RATE * 0.002))
        out.append((0.7 * math.sin(2 * math.pi * phase) + 0.3 * triangle(phase)) * env)
    return out


def sparkle(seconds: float, count: int, seed: int) -> list[float]:
    """A few tiny high bell ticks scattered over [seconds]."""
    rnd = random.Random(seed)
    track = silence(seconds)
    for _ in range(count):
        f = rnd.choice([NOTE["C7"], NOTE["A6"], NOTE["G6"], 2637.02])
        mix_into(track, bell(f, 0.18, decay=22, bright=0.0), rnd.uniform(0, seconds - 0.2), 0.18)
    return track


def normalise(track: list[float], peak: float) -> list[float]:
    top = max(abs(v) for v in track) or 1.0
    return [v * peak / top for v in track]


def fade_tail(track: list[float], seconds: float = 0.03) -> list[float]:
    n = min(len(track), int(RATE * seconds))
    for i in range(n):
        track[-1 - i] *= i / n
    return track


# ── The sounds ─────────────────────────────────────────────────────────


def tap() -> list[float]:
    return normalise(pluck(1400, 0.045), 0.35)


def select() -> list[float]:
    return normalise(pluck(990, 0.085, glide=0.06), 0.45)


def correct_after_mistake() -> list[float]:
    """Recovery: a warm low-to-high pair, softer than a fanfare."""
    t = silence(0.8)
    mix_into(t, bell(NOTE["G5"], 0.6, decay=5.5), 0.0, 0.8)
    mix_into(t, bell(NOTE["C6"], 0.7, decay=5.0), 0.11, 1.0)
    mix_into(t, pad([NOTE["C5"], NOTE["G5"]], 0.6), 0.1, 0.25)
    return fade_tail(normalise(t, 0.8))


def lesson_complete() -> list[float]:
    """Rising C-major arpeggio that settles on a held chord."""
    t = silence(1.7)
    for k, name in enumerate(["C5", "E5", "G5", "C6"]):
        mix_into(t, bell(NOTE[name], 0.9, decay=4.0), 0.09 * k, 0.75 + 0.08 * k)
    mix_into(t, pad([NOTE["C5"], NOTE["E5"], NOTE["G5"]], 1.4, fade_in=0.12), 0.3, 0.4)
    mix_into(t, sparkle(1.2, 5, seed=7), 0.35, 1.0)
    return fade_tail(normalise(t, 0.85))


def streak_extended() -> list[float]:
    """Bright, quick D-major lift with a little shimmer: warmth, not alarm."""
    t = silence(1.0)
    for k, name in enumerate(["D6", "F#6", "A6"]):
        mix_into(t, bell(NOTE[name], 0.6, decay=6.0, bright=0.15), 0.07 * k, 0.8)
    mix_into(t, pad([NOTE["D5"], NOTE["A5"]], 0.8), 0.15, 0.3)
    mix_into(t, sparkle(0.7, 4, seed=11), 0.2, 1.0)
    return fade_tail(normalise(t, 0.8))


def tier_up() -> list[float]:
    """The biggest one: a five-note climb to an octave-wide held chord."""
    t = silence(2.0)
    for k, name in enumerate(["C5", "G5", "C6", "E6", "G6"]):
        mix_into(t, bell(NOTE[name], 1.0, decay=3.5), 0.08 * k, 0.7 + 0.06 * k)
    mix_into(t, pad([NOTE["C5"], NOTE["G5"], NOTE["E6"]], 1.6, fade_in=0.15), 0.35, 0.45)
    mix_into(t, sparkle(1.4, 8, seed=23), 0.4, 1.0)
    return fade_tail(normalise(t, 0.85))


SYNTH = {
    "tap": tap,
    "select": select,
    "correct_after_mistake": correct_after_mistake,
    "lesson_complete": lesson_complete,
    "streak_extended": streak_extended,
    "tier_up": tier_up,
}

# Escalation: correct.mp3 itself is step 0. Steps 1-4 raise it by these
# semitones (a major-scale climb: 2, 4, 5, 7). The pitch shift resamples, so
# higher steps are also a little shorter, like a smaller bell.
CORRECT_STEPS = {1: 2, 2: 4, 3: 5, 4: 7}


def write_wav(path: str, samples: list[float]) -> None:
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in samples
        ))


def ffmpeg(*args: str) -> None:
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args], check=True)


def main() -> int:
    os.makedirs(BUILD, exist_ok=True)
    for name, make in SYNTH.items():
        wav = os.path.join(BUILD, f"{name}.wav")
        write_wav(wav, make())
        ffmpeg("-i", wav, "-ac", "1", "-codec:a", "libmp3lame", "-b:a", "96k",
               os.path.join(OUT, f"{name}.mp3"))
        print(f"assets/audio/{name}.mp3")

    source = os.path.join(OUT, "correct.mp3")
    for step, semitones in CORRECT_STEPS.items():
        ratio = 2 ** (semitones / 12)
        ffmpeg("-i", source, "-af", f"asetrate={RATE}*{ratio:.6f},aresample={RATE}",
               "-codec:a", "libmp3lame", "-b:a", "128k",
               os.path.join(OUT, f"correct_{step}.mp3"))
        print(f"assets/audio/correct_{step}.mp3 (+{semitones} semitones)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
