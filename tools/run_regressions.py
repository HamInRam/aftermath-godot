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
parser.add_argument("--output", type=Path, help="Directory for logs and summary.json")
parser.add_argument("scenes", nargs="*")
args = parser.parse_args()
project = Path(__file__).resolve().parents[1]
log_root = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix="aftermath-regression-"))
log_root.mkdir(parents=True, exist_ok=True)
scenes = args.scenes or [line.strip() for line in
    (project / "tests/regressions.txt").read_text().splitlines()
    if line.strip() and not line.lstrip().startswith("#")]
if not scenes or len(scenes) != len(set(scenes)):
    parser.error("Regression manifest must contain a nonempty unique scene list")
for scene in scenes:
    if not (project / scene).is_file():
        parser.error(f"Missing regression scene: {scene}")
jobs = ([] if args.skip_import else ["IMPORT"]) + scenes
results = []
print(f"Logs: {log_root}", flush=True)
for job in jobs:
    log = log_root / (Path(job).stem + ".log")
    command = [args.godot, "--headless", "--path", str(project), "--log-file", str(log)]
    command += ["--editor", "--quit"] if job == "IMPORT" else [job]
    started = time.monotonic()
    combined_log = log.with_suffix(".output.log")
    reason = ""
    with combined_log.open("w") as capture:
        process = subprocess.Popen(command, stdout=capture, stderr=subprocess.STDOUT, text=True)
        try:
            while process.poll() is None:
                time.sleep(0.1)
                output = combined_log.read_text(errors="replace")
                if re.search(r"SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script", output):
                    reason = "Script failed; scene terminated instead of waiting on a stopped coroutine"
                    break
                if time.monotonic() - started >= args.timeout:
                    reason = f"TIMEOUT after {args.timeout}s"
                    break
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    output = combined_log.read_text(errors="replace")
    code = process.returncode
    if reason:
        code = 124 if reason.startswith("TIMEOUT") else 1
        output += "\n" + reason + "\n"
        combined_log.write_text(output)
    # Engine errors fail even when Godot exits zero. Teardown diagnostics are
    # tracked separately so they cannot be mistaken for a clean leak audit.
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
    (log_root / "summary.json").write_text(json.dumps(results, indent=2) + "\n")
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
