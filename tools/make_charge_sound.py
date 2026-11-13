# Usage: python tools/make_charge_sound.py assets/sfx/charge.wav
"""Generates the shotgun charge-up sound: a retro synth riser (like a classic power-up) but in a
low, mellow register. It sweeps up over the 0.4 s charge, then holds a soft warbling note while
the charge is held. Writes a 16-bit mono WAV."""
import sys
import wave
import numpy as np

OUT = sys.argv[1]
SR = 44100
BUILD = 0.40          # matches FULL_CHARGE_TIME in player.gd
LENGTH = 2.2
START_HZ = 140.0      # where the sweep starts
END_HZ = 330.0        # where it lands at full charge (about E4: mid, not squeaky)
t = np.arange(int(SR * LENGTH)) / SR

build = np.clip(t / BUILD, 0.0, 1.0)
# Exponential sweep sounds even to the ear; a little overshoot at the end makes it "lock in".
freq = START_HZ * (END_HZ / START_HZ) ** build
freq *= 1.0 + 0.01 * np.sin(2 * np.pi * 9.0 * t) * (t > BUILD)   # gentle vibrato once full
phase = 2 * np.pi * np.cumsum(freq) / SR

# Soft square (few odd harmonics) for the retro feel, plus a sine an octave down for body.
square = np.sin(phase) + np.sin(3 * phase) / 3 + np.sin(5 * phase) / 5 * 0.5
sub = np.sin(phase / 2) * 0.5
tone = square * 0.6 + sub

# Round off the top end so it never gets harsh.
out = np.zeros_like(tone)
state = 0.0
a = 1.0 - np.exp(-2 * np.pi * 1600.0 / SR)
for i in range(len(tone)):
    state += a * (tone[i] - state)
    out[i] = state

# Level: rises with the charge, a small bump when it reaches full, then a softer held note.
env = 0.45 + 0.55 * build
env *= 1.0 + 0.25 * np.exp(-np.clip(t - BUILD, 0, None) / 0.06) * (t >= BUILD)
env *= np.where(t > BUILD, 0.75 + 0.1 * np.sin(2 * np.pi * 5.0 * (t - BUILD)), 1.0)
env *= np.clip(t / 0.015, 0.0, 1.0)                 # click-free start
env *= np.clip((LENGTH - t) / 0.4, 0.0, 1.0)        # fade if held to the end
out *= env
out *= 0.5 / np.abs(out).max()

pcm = (out * 32767).astype(np.int16)
with wave.open(OUT, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(SR)
    f.writeframes(pcm.tobytes())
print("wrote", OUT)
