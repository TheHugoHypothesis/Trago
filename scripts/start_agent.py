#!/usr/bin/env python3
"""One command per MVP writer; all inference/builds happen in rootless Podman."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import fcntl
import json
from pathlib import Path
import subprocess
import sys

from agents import Controller, Error
import podman_env


ROOT = Path(__file__).resolve().parents[1]
JOBS = {
    "frontend": ("MVP-frontend", "agy"),
    "backend": ("MVP-backend", "codex"),
    "android": ("MVP-android", "pi"),
}


def seed_profiles():
    state = ROOT / ".agent-state"
    state.mkdir(exist_ok=True)
    with (state / "profiles.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for engine, marker in [("codex", ".codex/auth.json"), ("pi", ".pi/agent/auth.json"),
                               ("agy", ".gemini/antigravity-cli/settings.json")]:
            if not (state / "profiles" / engine / marker).exists():
                podman_env.import_profile(ROOT, engine, skip_existing=True)


def start(component, prepare_only=False, model=None, provider=None):
    identifier, engine = JOBS[component]
    controller = Controller(ROOT)
    record = controller.records().get(identifier)
    if record is None:
        record = controller.prepare(identifier, engine + "-" + component)
    if prepare_only:
        print(json.dumps({"task": identifier, "worktree": record["worktree"], "status": record["status"]}, indent=2))
        return 0
    if record["status"] != "CLAIMED":
        print(f"{identifier}: status {record['status']}; inspect existing logs, do not overwrite work", file=sys.stderr)
        return 2
    seed_profiles()
    if component == "backend":
        podman_env.database(ROOT, identifier)
    print(f"Starting {identifier} with {engine} in Podman; log: {record['worktree']}/.task/agent.log", flush=True)
    result = controller.run_with_handoff(identifier, engine=engine, model=model, provider=provider,
                                         pi_harness=True, agy_skip_permissions=True)
    if result["exit_code"] == 0:
        controller.verify(identifier)
    print(json.dumps({"task": identifier, **result}, indent=2, ensure_ascii=False))
    return result["exit_code"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("component", choices=[*JOBS, "all"])
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--model", help="Optional model override; omit to use installed harness configuration")
    parser.add_argument("--provider", help="Pi provider; requires --model")
    args = parser.parse_args()
    if args.provider and (args.component != "android" or not args.model):
        parser.error("--provider requires android and --model")
    try:
        if args.component == "all":
            with ThreadPoolExecutor(max_workers=3) as pool:
                results = list(pool.map(lambda name: start(name, args.prepare_only), JOBS))
            return 0 if all(code == 0 for code in results) else 1
        return start(args.component, args.prepare_only, args.model, args.provider)
    except (Error, OSError, ValueError, subprocess.SubprocessError) as exc:
        print(f"start-agent: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
