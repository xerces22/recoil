# Puts a loudness ceiling on the game's audio, in place. Originals are kept in
# ../downloads/_audio_originals. Safe to re-run: files already under the ceiling are untouched.
#
# SFX and jingles: if the loudest 50 ms is above SFX_CEILING, turn the file down to it.
#                  Quieter files are left alone (the scripts mix them with volume_db).
# Music:           every track to MUSIC_LUFS integrated loudness, so tracks match each other.
# Everything:      peaks limited to PEAK_DB.
#
# Usage: python -I tools/normalize_audio.py <project dir>
import sys, subprocess, glob, os, json, re
import numpy as np

SFX_CEILING = -16.0
MUSIC_LUFS = -18.0
PEAK_DB = -1.0

def decode(f):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", f, "-ac", "1", "-ar", "24000", "-f", "f32le", "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32)

def loud50(f):
    x = decode(f)
    w = 1200
    sq = np.convolve(x * x, np.ones(w) / w, mode="valid") if x.size > w else np.array([np.mean(x * x)])
    return 10 * np.log10(np.max(sq) + 1e-12), 20 * np.log10(np.max(np.abs(x)) + 1e-9)

def lufs(f):
    err = subprocess.run(["ffmpeg", "-hide_banner", "-i", f, "-af", "loudnorm=print_format=json", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    return float(json.loads(re.search(r"\{[^{}]*\}", err, re.S).group(0))["input_i"])

def codec_args(f):
    ext = os.path.splitext(f)[1].lower()
    return {".ogg": ["-c:a", "libvorbis", "-q:a", "6"], ".mp3": ["-c:a", "libmp3lame", "-b:a", "192k"],
            ".wav": ["-c:a", "pcm_s16le"]}[ext]

def apply(f, gain_db):
    tmp = f + ".tmp" + os.path.splitext(f)[1]
    limit = 10 ** (PEAK_DB / 20)
    af = f"volume={gain_db:.2f}dB,alimiter=limit={limit:.4f}:level=0:attack=2:release=40"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", f, "-af", af, *codec_args(f), tmp], check=True)
    os.replace(tmp, f)

root = sys.argv[1]
sfx = sorted(glob.glob(root + "/assets/sfx/*.*") + glob.glob(root + "/assets/music/jingles/*.*"))
music = sorted(glob.glob(root + "/assets/music/*.*"))
for f in sfx + music:
    if f.endswith(".import") or ".tmp" in f:
        continue
    name = os.path.relpath(f, root)
    if f in music:
        before = lufs(f)
        gain = MUSIC_LUFS - before
        apply(f, gain)
        print(f"{name:44} {before:6.1f} LUFS  -> gain {gain:+5.1f} dB")
    else:
        l, peak = loud50(f)
        gain = min(0.0, SFX_CEILING - l)
        if gain > -0.3 and peak <= PEAK_DB:
            print(f"{name:44} {l:6.1f} dB   ok")
            continue
        apply(f, gain)
        print(f"{name:44} {l:6.1f} dB   -> gain {gain:+5.1f} dB")
