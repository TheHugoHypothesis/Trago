#!/usr/bin/env python3
"""Rootless Podman environment for agent processes and all product builds."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


IMAGE = "localhost/trago-dev:node22-jdk17"
BASE = "docker.io/library/node:22-bookworm-slim"


def slug(value):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", value):
        raise ValueError("Invalid environment ID")
    return value.lower().replace("_", "-")


def namespace(root, identifier):
    project = hashlib.sha256(str(Path(root).resolve()).encode()).hexdigest()[:8]
    return "trago-" + project + "-" + slug(identifier)


def installed_tools():
    result = {}
    for engine in ["codex", "agy"]:
        executable = shutil.which(engine)
        if executable:
            result[engine] = Path(executable).resolve()
    # The managed pi launcher contains host paths. Mount its installed release,
    # and invoke the package using the container's compatible Node runtime.
    pi = shutil.which("pi")
    if pi:
        launcher = Path(pi).resolve()
        managed = launcher.parent.parent
        version_file = managed / "install/current-version"
        if version_file.is_file():
            version = version_file.read_text().strip()
            if re.fullmatch(r"[A-Za-z0-9._+-]+", version):
                release = managed / "install/releases" / version
                if (release / "node_modules/@earendil-works/pi-coding-agent/package.json").is_file():
                    result["pi"] = release
    sdk = Path(os.environ.get("ANDROID_HOME", str(Path.home() / "Android/Sdk"))).expanduser().resolve()
    if (sdk / "platforms").is_dir():
        result["android_sdk"] = sdk
    return result


def command(root, workspace, identifier, argv, engine=None, name=None):
    """Build argv only. No container creation, global config writes or model calls."""
    root, workspace = Path(root).resolve(), Path(workspace).resolve()
    key = namespace(root, identifier)
    if not workspace.is_relative_to(root):
        raise ValueError("Workspace must be inside coordinator repository")
    profile = root / ".agent-state/profiles" / (engine or "build")
    if profile.is_symlink() or not profile.resolve().is_relative_to(root):
        raise ValueError("Profile must not be a symlink")
    for path in [root, workspace, profile]:
        if "," in str(path) or "\n" in str(path):
            raise ValueError("Unsupported mount path")
    if not argv or any(not isinstance(arg, str) or "\x00" in arg for arg in argv):
        raise ValueError("Command must be argv")
    mounts = [f"type=bind,src={workspace},dst={workspace},rw",
              f"type=bind,src={profile},dst=/home/node,rw",
              f"type=volume,src={key}-cache,dst=/cache"]
    # Git worktree .git files use absolute paths into the shared common directory.
    # It is readable, never writable, inside agent containers.
    if (root / ".git").is_dir():
        mounts.append(f"type=bind,src={root / '.git'},dst={root / '.git'},ro")
    if engine and (workspace / "contracts").is_dir():
        mounts.append(f"type=bind,src={workspace / 'contracts'},dst={workspace / 'contracts'},ro")
    assets = root / "InitialAssets"
    if assets.is_dir():
        if workspace == root:
            mounts.append(f"type=bind,src={assets},dst={assets},ro")
        elif engine:
            mounts.append(f"type=bind,src={assets},dst=/opt/trago-assets,ro")
    tools = installed_tools()
    if engine:
        if engine not in {"codex", "agy", "pi"} or engine not in tools:
            raise ValueError(f"Installed CLI not found: {engine}")
        target = "/opt/pi" if engine == "pi" else f"/opt/agents/{engine}"
        mounts.append(f"type=bind,src={tools[engine]},dst={target},ro")
    if "android_sdk" in tools:
        mounts.append(f"type=bind,src={tools['android_sdk']},dst=/opt/android-sdk,ro")
    result = ["podman", "run", "--rm", "--init", "--pull=never", "--read-only",
              "--userns=keep-id", "--user", f"{os.getuid()}:{os.getgid()}",
              "--cap-drop=ALL", "--security-opt=no-new-privileges",
              # Read-only host-installed tools/SDK retain their original SELinux labels.
              # Disable container label separation instead of relabeling user installations.
              "--security-opt=label=disable", "--pids-limit=512", "--memory=6g", "--cpus=4",
              "--tmpfs=/tmp:rw,exec,nosuid,nodev,size=1g", "--tmpfs=/run:rw,nosuid,nodev,size=32m",
              "--network", key, "--workdir", str(workspace),
              "--env", "TRAGO_CONTAINER=1",
              "--env", f"DATABASE_URL=postgresql://trago:trago-local@db:5432/trago"]
    if name:
        result += ["--name", name]
    if engine == "codex":
        result += ["--interactive"]
    for mount in mounts:
        result += ["--mount", mount]
    lock = root / "containers/images.lock.json"
    image = json.loads(lock.read_text()).get("toolchain_image_id", IMAGE) if lock.exists() else IMAGE
    if image != IMAGE and not re.fullmatch(r"sha256:[0-9a-f]{64}", image):
        raise ValueError("Invalid pinned toolchain image ID")
    return result + [image, *argv]


def ensure(root, identifier, engine=None):
    root = Path(root).resolve()
    profile = root / ".agent-state/profiles" / (engine or "build")
    if profile.is_symlink() or not profile.resolve().is_relative_to(root):
        raise ValueError("Unsafe profile directory")
    profile.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(profile, 0o700)
    network = namespace(root, identifier)
    if subprocess.run(["podman", "network", "exists", network], capture_output=True).returncode:
        subprocess.run(["podman", "network", "create", network], check=True, stdout=subprocess.DEVNULL)


def build(root):
    root = Path(root).resolve()
    lock = root / "containers/images.lock.json"
    if lock.exists():
        base = json.loads(lock.read_text())["toolchain_base"]
    else:
        subprocess.run(["podman", "pull", BASE], check=True)
        data = json.loads(subprocess.check_output(["podman", "image", "inspect", BASE]))[0]
        base = data["RepoDigests"][0]
        lock.write_text(json.dumps({"toolchain_base": base}, indent=2) + "\n")
    if not re.fullmatch(r"[a-zA-Z0-9./:_-]+@sha256:[0-9a-f]{64}", base):
        raise ValueError("Image base must be pinned to a registry digest")
    subprocess.run(["podman", "build", "--pull=missing", "--build-arg", f"BASE_IMAGE={base}",
                    "--tag", IMAGE, "--file", str(root / "containers/Containerfile"),
                    str(root / "containers")], check=True)
    image_id = subprocess.check_output(["podman", "image", "inspect", "--format", "{{.Id}}", IMAGE], text=True).strip()
    if re.fullmatch(r"[0-9a-f]{64}", image_id):
        image_id = "sha256:" + image_id
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", image_id):
        raise ValueError("Podman returned an invalid image ID")
    lock.write_text(json.dumps({"toolchain_base": base, "toolchain_image_id": image_id}, indent=2) + "\n")


def stop(name):
    if not name.startswith("trago-"):
        raise ValueError("Only task containers may be stopped")
    subprocess.run(["podman", "stop", "--ignore", "--time", "2", name],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)


def database(root, identifier):
    """Local demo PostgreSQL, private task network, no published port or host data mount."""
    ensure(root, identifier)
    name = namespace(root, identifier) + "-db"
    exists = subprocess.run(["podman", "container", "exists", name], capture_output=True).returncode == 0
    if exists:
        subprocess.run(["podman", "start", name], check=True, stdout=subprocess.DEVNULL)
    else:
        subprocess.run(["podman", "run", "--detach", "--name", name, "--pull=missing",
                        "--network", namespace(root, identifier), "--network-alias", "db",
                        "--memory=1g", "--pids-limit=256",
                        "--mount", f"type=volume,src={name}-data,dst=/var/lib/postgresql/data",
                        "--env", "POSTGRES_USER=trago", "--env", "POSTGRES_PASSWORD=trago-local",
                        "--env", "POSTGRES_DB=trago", "docker.io/library/postgres:17-bookworm"],
                       check=True, stdout=subprocess.DEVNULL)
    for _ in range(30):
        result = subprocess.run(["podman", "exec", name, "pg_isready", "-U", "trago", "-d", "trago"],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode == 0:
            return name
        time.sleep(1)
    raise ValueError("Local PostgreSQL did not become ready; inspect its container logs")


def import_profile(root, engine, skip_existing=False):
    """Explicit import only; secrets never enter an image, Git, stdout or argv."""
    root = Path(root).resolve()
    source = Path.home()
    selected = {
        "codex": [".codex/auth.json"],
        "pi": [".pi/agent/auth.json", ".pi/agent/models.json", ".pi/agent/settings.json"],
        "agy": [".gemini/antigravity-cli/settings.json", ".gemini/antigravity-cli/jetski_state.pbtxt",
                ".gemini/antigravity-cli/installation_id", ".gemini/oauth_creds.json"],
    }[engine]
    target = root / ".agent-state/profiles" / engine
    if target.is_symlink() or not target.resolve().is_relative_to(root):
        raise ValueError("Unsafe profile target")
    candidates = [relative for relative in selected if (source / relative).is_file()]
    if skip_existing:
        candidates = [relative for relative in candidates if not (target / relative).exists()]
    for relative in candidates:
        destination = target / relative
        if destination.exists() or destination.is_symlink() or not destination.resolve().is_relative_to(target.resolve()):
            raise ValueError("Existing or unsafe profile is preserved; import into a new profile only")
    target.mkdir(parents=True, exist_ok=True, mode=0o700)
    count = 0
    for relative in candidates:
        original = source / relative
        if not original.is_file():
            continue
        destination = target / relative
        if destination.exists() or destination.is_symlink():
            raise ValueError("Existing profile is preserved; import into a new profile only")
        destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        shutil.copyfile(original, destination)
        os.chmod(destination, 0o600)
        count += 1
    print(f"Imported {count} selected profile files; no credentials printed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("build")
    sub.add_parser("doctor")
    run = sub.add_parser("run")
    run.add_argument("--task", default="foundation")
    run.add_argument("--engine", choices=["codex", "agy", "pi"])
    run.add_argument("--workspace", type=Path)
    run.add_argument("--execute", action="store_true")
    run.add_argument("argv", nargs=argparse.REMAINDER)
    imp = sub.add_parser("import-profile")
    imp.add_argument("engine", choices=["codex", "pi", "agy"])
    args = parser.parse_args()
    try:
        if args.command == "build":
            build(args.root)
        elif args.command == "doctor":
            subprocess.run(["podman", "info", "--format", "{{.Host.Security.Rootless}}"], check=True)
            ensure(args.root, "doctor")
            for argv in [["node", "--version"], ["npm", "--version"], ["python3", "--version"],
                         ["java", "-version"], ["git", "--version"]]:
                subprocess.run(command(args.root, args.root, "doctor", argv), check=True)
        elif args.command == "import-profile":
            import_profile(args.root, args.engine)
        else:
            argv = args.argv[1:] if args.argv[:1] == ["--"] else args.argv
            wrapped = command(args.root, args.workspace or args.root, args.task, argv, args.engine)
            if not args.execute:
                print(json.dumps({"preview": True, "argv": wrapped}, indent=2))
                return 0
            ensure(args.root, args.task, args.engine)
            return subprocess.run(wrapped).returncode
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"podman-env: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
