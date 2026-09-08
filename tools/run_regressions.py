#!/usr/bin/env python3
"""Run the CI scene list sequentially with bounded runtimes and separate logs."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument("--godot", default="godot")
parser.add_argument("--timeout", type=int, default=120)
parser.add_argument("--skip-import", action="store_true")
parser.add_argument("scenes", nargs="*")
args = parser.parse_args()
project = Path(__file__).resolve().parents[1]
log_root = Path(tempfile.mkdtemp(prefix="aftermath-regression-"))
scenes = args.scenes or list(dict.fromkeys(re.findall(
    r"tests/test_[a-z0-9_]+\.tscn",
    (project / ".github/workflows/godot-tests.yml").read_text(),
)))
jobs = ([] if args.skip_import else ["IMPORT"]) + scenes
results = []
print(f"Logs: {log_root}", flush=True)
for job in jobs:
    log = log_root / (Path(job).stem + ".log")
    command = [args.godot, "--headless", "--path", str(project), "--log-file", str(log)]
    command += ["--editor", "--quit"] if job == "IMPORT" else [job]
    started = time.monotonic()
    try:
        process = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
        output = process.stdout + process.stderr
        code = process.returncode
    except subprocess.TimeoutExpired as error:
        output = f"TIMEOUT after {args.timeout}s\n{error}"
        code = 124
    # Godot can return zero even after a renderer/engine error. Retain stderr
    # and fail those errors too; known shutdown diagnostics remain explicit.
    combined_log = log.with_suffix(".output.log")
    combined_log.write_text(output)
    unexpected_error = any(
        re.search(r"^(?:SCRIPT )?ERROR:", line) and "resources still in use at exit" not in line
        for line in output.splitlines()
    )
    failed = code != 0 or unexpected_error or bool(re.search(r"Parse Error|Compile Error|Failed to load script", output))
    diagnostics = ("ObjectDB instances" in output and "leaked at exit" in output) or "resources still in use" in output
    result = {"scene": job, "passed": not failed, "exit_code": code,
              "seconds": round(time.monotonic() - started, 2), "shutdown_warnings": diagnostics,
              "log": str(log), "combined_log": str(combined_log)}
    results.append(result)
    print(f"{'FAIL' if failed else 'PASS'} {job} ({result['seconds']}s)" +
          (" [shutdown warning]" if diagnostics else ""), flush=True)
    if failed:
        print(output[-8000:], flush=True)
    if job == "IMPORT" and failed:
        break
summary = log_root / "summary.json"
summary.write_text(json.dumps(results, indent=2) + "\n")
failed_count = sum(not entry["passed"] for entry in results)
print(f"{len(results) - failed_count}/{len(results)} passed; report: {summary}", flush=True)
raise SystemExit(1 if failed_count else 0)
