#!/usr/bin/env python3
"""Генерирует 4 встроенных тембра: WAV 44,1 кГц / 16 бит / моно, не длиннее 60 мс.

Запуск: python3 scripts/gen_sounds.py  (файлы пишутся в Resources/Sounds)
Пиковый уровень ~0.5 FS: остаётся запас, чтобы акцентный удар звучал громче.
"""
import math
import os
import random
import struct
import wave

SR = 44_100
PEAK = 0.5
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Sounds")


def finish(samples, fade_ms=3.0):
    n = len(samples)
    fade = int(SR * fade_ms / 1000)
    for i in range(fade):
        samples[n - 1 - i] *= i / fade
    m = max(abs(s) for s in samples) or 1.0
    return [s / m * PEAK for s in samples]


def lowpass(samples, alpha):
    out, y = [], 0.0
    for s in samples:
        y += alpha * (s - y)
        out.append(y)
    return out


def click():
    rnd = random.Random(1)
    n = int(SR * 0.025)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t / 0.0025)
        out.append(env * (0.6 * math.sin(2 * math.pi * 3200 * t) + 0.4 * (rnd.random() * 2 - 1)))
    return finish(out)


def woodblock():
    rnd = random.Random(2)
    n = int(SR * 0.060)
    out = []
    for i in range(n):
        t = i / SR
        body = math.exp(-t / 0.012) * (math.sin(2 * math.pi * 880 * t) + 0.5 * math.sin(2 * math.pi * 1720 * t))
        attack = math.exp(-t / 0.0008) * (rnd.random() * 2 - 1) * 0.4
        out.append(body + attack)
    return finish(out)


def soft_tick():
    rnd = random.Random(3)
    n = int(SR * 0.020)
    noise = [rnd.random() * 2 - 1 for _ in range(n)]
    noise = lowpass(lowpass(noise, 0.25), 0.25)
    out = [noise[i] * math.exp(-(i / SR) / 0.003) for i in range(n)]
    # тихий тик: нормируем ниже остальных
    return [s * 0.45 for s in finish(out)]


def soft_beep():
    n = int(SR * 0.060)
    attack = int(SR * 0.004)
    out = []
    for i in range(n):
        t = i / SR
        env = (i / attack) if i < attack else math.exp(-(t - attack / SR) / 0.018)
        out.append(env * math.sin(2 * math.pi * 1046.5 * t))
    return finish(out, fade_ms=8)


def write(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
    print(f"{path}: {len(samples) / SR * 1000:.0f} ms")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("click", click())
    write("woodblock", woodblock())
    write("soft_tick", soft_tick())
    write("soft_beep", soft_beep())
