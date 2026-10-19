#!/usr/bin/env python3
"""Preview the API/Web directly from their separate worktrees; never merge code."""
import argparse
from pathlib import Path
import subprocess
import sys

from agents import Controller, Error
import podman_env


ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["up", "down", "logs"])
    args = parser.parse_args()
    try:
        key = podman_env.namespace(ROOT, "mvp")
        names = {"backend": key + "-api", "frontend": key + "-web"}
        if args.command == "down":
            for name in names.values():
                podman_env.stop(name)
            return 0
        if args.command == "logs":
            for name in names.values():
                subprocess.run(["podman", "logs", "--tail", "40", name])
            return 0
        records = Controller(ROOT).records()
        for task, folder in [("MVP-backend", "api"), ("MVP-frontend", "web")]:
            if task not in records or not (Path(records[task]["worktree"]) / "apps" / folder / "package.json").is_file():
                raise Error("API/Web code is not ready; start the coding agents first")
        podman_env.database(ROOT, "MVP-backend")
        for component, task, folder, port in [("backend", "MVP-backend", "api", 3001),
                                             ("frontend", "MVP-frontend", "web", 3000)]:
            wt = Path(records[task]["worktree"])
            argv = podman_env.command(ROOT, wt, "MVP-backend", ["npm", "--prefix", "apps/" + folder, "run", "dev"],
                                     name=names[component])
            options = ["--detach", "--publish", f"127.0.0.1:{port}:{port}"]
            if component == "backend":
                options += ["--network-alias", "api"]
            else:
                options += ["--env", "NEXT_PUBLIC_API_BASE_URL=http://localhost:3001",
                            "--env", "API_BASE_URL=http://api:3001"]
            argv[2:2] = options
            podman_env.stop(names[component])
            subprocess.run(argv, check=True)
        print("Web: http://localhost:3000 | API: http://localhost:3001 | inspect logs with make mvp-logs")
        return 0
    except (Error, OSError, ValueError, subprocess.SubprocessError) as exc:
        print(f"mvp: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
