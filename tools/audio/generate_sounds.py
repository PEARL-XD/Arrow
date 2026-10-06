"""Generate original, sample-free game cues (Python standard library only).

Run from any directory. WAV assets are deterministic, mono 48 kHz / 16 bit.
No downloaded recordings, speech, or third-party music are used.
"""
from pathlib import Path
from array import array
import math
import random
import sys
import wave

ROOT = Path(__file__).resolve().parents[2]
RATE = 48000


def note(frequency, duration, gain=0.3, bright=False):
    result = []
    for i in range(round(duration * RATE)):
        t = i / RATE
        attack = min(1, t / 0.008)
        end = min(1, (duration - t) / 0.035)
        envelope = attack * end * math.exp(-t * (5 if bright else 8))
        phase = 2 * math.pi * frequency * t
        tone = math.sin(phase) + 0.22 * math.sin(phase * 2.01)
        if bright:
            tone += 0.12 * math.sin(phase * 3.98)
        result.append(gain * envelope * tone)
    return result


def phrase(notes, spacing, duration=0.3, gain=0.24):
    result = [0.0] * round((spacing * (len(notes) - 1) + duration) * RATE)
    for j, frequency in enumerate(notes):
        start = round(j * spacing * RATE)
        for i, sample in enumerate(note(frequency, duration, gain, bright=True)):
            if start + i < len(result):
                result[start + i] += sample
    return result


def glide():
    rng = random.Random(811)
    result, filtered, phase = [], 0.0, 0.0
    duration = 0.24
    for i in range(round(duration * RATE)):
        t = i / RATE
        p = t / duration
        filtered += 0.16 * (rng.uniform(-1, 1) - filtered)
        phase += 2 * math.pi * (420 + 640 * p) / RATE
        envelope = math.sin(math.pi * p) ** 1.8
        result.append(envelope * (filtered * 0.34 + math.sin(phase) * 0.08))
    return result


def knock():
    rng = random.Random(23)
    result = []
    for i in range(round(0.23 * RATE)):
        t = i / RATE
        envelope = min(1, t / 0.004) * math.exp(-t * 24)
        frequency = 185 - 65 * min(1, t / 0.1)
        result.append(envelope * (0.24 * math.sin(2 * math.pi * frequency * t)
                                  + rng.uniform(-0.045, 0.045)))
    return result


def save(path, samples):
    path.parent.mkdir(parents=True, exist_ok=True)
    # Soft saturation and a conservative ceiling avoid harsh peaks on phones.
    pcm = array('h', (round(math.tanh(x) * 0.78 * 32767) for x in samples))
    if sys.byteorder != 'little':
        pcm.byteswap()
    with wave.open(str(path), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def main():
    cues = {
        'glide': glide(),
        'good': note(784, 0.18, 0.20),
        'nice': phrase([659.25, 987.77], 0.085, 0.24, 0.21),
        'great': phrase([659.25, 830.61, 1108.73], 0.085, 0.32, 0.22),
        'blocked': knock(),
        'pause': phrase([587.33, 440], 0.095, 0.22, 0.17),
        'resume': phrase([440, 587.33], 0.08, 0.23, 0.17),
        'hint': phrase([880, 1318.51], 0.14, 0.4, 0.17),
        'victory': phrase([523.25, 659.25, 783.99, 1046.5], 0.12, 0.65, 0.25),
        'loss': knock() + phrase([392, 329.63, 261.63], 0.12, 0.3, 0.16),
    }
    preview = []
    for name, samples in cues.items():
        save(ROOT / 'assets' / 'audio' / f'{name}.wav', samples)
        preview += samples + [0.0] * round(0.45 * RATE)
        print(f'{name}: {len(samples) / RATE:.2f}s')
    save(ROOT / 'work' / 'audio-preview.wav', preview)


if __name__ == '__main__':
    main()
