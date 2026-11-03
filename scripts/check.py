#!/usr/bin/env python3
"""Compile every GDScript; Godot may log parser errors with a zero exit code."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT", "godot")

def run(args):
    result = subprocess.run([GODOT, "--headless", "--path", str(ROOT / "game"), *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout, end="")
    return result.returncode == 0 and not any(marker in result.stdout for marker in ("SCRIPT ERROR:", "Parse Error:", "ERROR:"))

if not run(["--editor", "--import", "--quit"]):
    sys.exit(1)
for path in sorted((ROOT / "game").rglob("*.gd")):
    if ".godot" in path.parts:
        continue
    if not run(["--check-only", "--script", "res://" + path.relative_to(ROOT / "game").as_posix()]):
        sys.exit(1)
if "--parse-only" not in sys.argv:
    args = sys.argv[1:]
    if not run(["--script", "res://tests/run_tests.gd", "--", *args]):
        sys.exit(1)
