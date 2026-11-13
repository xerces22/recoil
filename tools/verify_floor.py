"""Build, solve and replay one floor in one go.

    python tools/verify_floor.py 3            # floor 3: build, solver, real-game replay
    python tools/verify_floor.py 3 --no-replay

The floor must already be registered in FLOORS in main.gd (the replay loads it by index).
"""
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
GODOT = r"C:\Users\Administrator\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"

sys.path.insert(0, HERE)
import build_floors  # noqa: E402


def main():
    n = int(sys.argv[1])
    path = build_floors.FLOORS[n]()
    rel = os.path.relpath(path, ROOT).replace("\\", "/")
    plans = os.path.join(HERE, f"plans_{n:02d}.json")
    print(f"== floor {n}: {rel}")
    solver = subprocess.run([sys.executable, os.path.join(HERE, "floor_solver.py"), rel, f"--plans={plans}"],
                            cwd=ROOT, capture_output=True, text=True)
    print(solver.stdout.rstrip())
    if solver.returncode != 0 or "--no-replay" in sys.argv:
        sys.exit(solver.returncode)
    floors = re.findall(r'"res://levels/([^"]+)"', open(os.path.join(ROOT, "main.gd"), encoding="utf-8").read().split("SANDBOXES")[0])
    index = floors.index(os.path.basename(path))
    tmp = os.path.join(ROOT, f"_replay_tmp_{n}.gd")
    shutil.copy(os.path.join(HERE, "replay_floor.gd"), tmp)
    try:
        rep = subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", f"res://_replay_tmp_{n}.gd", "--", str(index), plans],
                             cwd=ROOT, capture_output=True, text=True, timeout=1500)
        lines = [l for l in rep.stdout.splitlines() if re.match(r"(REPLAY|  ok|  FAIL|RESULT)", l)]
        errors = [l for l in (rep.stdout + rep.stderr).splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l]
        print("\n".join(lines + errors[:5]))
    finally:
        for p in (tmp, tmp + ".uid"):
            if os.path.exists(p):
                os.remove(p)
    sys.exit(rep.returncode)


if __name__ == "__main__":
    main()
