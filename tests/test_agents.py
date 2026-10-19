"""Behavioral tests: no real model calls or changes to the user's repository."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import sys
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
import threading
from unittest import mock


MODULE = Path(__file__).resolve().parents[1] / "scripts" / "agents.py"


def task(identifier="T01", paths=None, dependencies=None):
    return {
        "id": identifier, "spec": "specs/slice.md", "description": "Implementar fluxo privado",
        "role": "implementer", "agent": "codex", "dependencies": dependencies or [],
        "allowed_paths": paths or ["apps/api/"], "expected_outputs": ["apps/api/result.txt"],
        "acceptance_criteria": ["Persistir e autorizar"],
        "verification_commands": [["python3", "-c", "print('verified')"]],
        "risk": "medium", "max_retries": 1, "timeout_seconds": 5,
        "approved": True,
    }


class ControllerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("trago_agents", MODULE)
        cls.api = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.api)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="trago testes ç ")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "repo espaço"
        self.root.mkdir()
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        (self.root / "specs").mkdir()
        (self.root / "specs/slice.md").write_text("Approved local spec\n")
        (self.root / "AGENTS.md").write_text("Do not push or change assets.\n")
        (self.root / ".gitignore").write_text(".agent-state/\n.worktrees/\n.task/\n")
        (self.root / "orchestration").mkdir()
        self.write_tasks([task()])
        self.git("add", ".")
        self.git("commit", "-m", "fixture")

    def git(self, *args, cwd=None, check=True):
        return subprocess.run(["git", *args], cwd=cwd or self.root, capture_output=True,
                              text=True, check=check)

    def write_tasks(self, tasks):
        (self.root / "orchestration/tasks.json").write_text(json.dumps({"version": 1, "tasks": tasks}))

    def controller(self):
        return self.api.Controller(self.root, containers=False)

    def prepare(self):
        return self.controller().prepare("T01", "codex-api")

    def output(self, record):
        p = Path(record["worktree"]) / "apps/api/result.txt"
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("behavior implemented\n")
        return p

    def test_invalid_dag_and_scope(self):
        for tasks in [[task(), task()], [task(dependencies=["missing"])],
                      [task("T01", dependencies=["T02"]), task("T02", dependencies=["T01"])]]:
            with self.subTest(tasks=tasks), self.assertRaises(self.api.Error):
                self.api.validate({"version": 1, "tasks": tasks})
        for path in ["../escape", "/tmp/path", ".git/config", "apps/../../secret", "apps//api"]:
            with self.subTest(path=path), self.assertRaises(self.api.Error):
                self.api.validate({"version": 1, "tasks": [task(paths=[path])]})

    def test_expected_output_must_be_in_scope(self):
        t = task(paths=["apps/web/"])
        with self.assertRaises(self.api.Error):
            self.api.validate({"version": 1, "tasks": [t]})

    def test_dependency_must_be_integrated_before_prepare(self):
        self.write_tasks([task(), task("T02", dependencies=["T01"])])
        self.git("add", "orchestration/tasks.json")
        self.git("commit", "-m", "dependency")
        with self.assertRaises(self.api.Error):
            self.controller().prepare("T02", "web")

    def test_prepare_requires_committed_context(self):
        (self.root / "specs/slice.md").write_text("uncommitted changes\n")
        with self.assertRaises(self.api.Error):
            self.prepare()

    def test_prepare_creates_isolated_worktree_and_prompt(self):
        r = self.prepare()
        worktree = Path(r["worktree"])
        self.assertNotEqual(worktree, self.root)
        self.assertTrue((worktree / ".git").is_file())
        self.assertTrue((worktree / ".task/TASK.md").is_file())
        self.assertIn("apps/api/", (worktree / ".task/TASK.md").read_text())
        self.assertEqual(self.git("branch", "--show-current").stdout.strip(), "main")

    def test_parallel_overlap_rejected(self):
        self.write_tasks([task(), task("T02")])
        self.git("add", "orchestration/tasks.json")
        self.git("commit", "-m", "overlap")
        self.prepare()
        with self.assertRaises(self.api.Error):
            self.controller().prepare("T02", "second")

    def test_duplicate_claim_rejected(self):
        self.prepare()
        with self.assertRaises(self.api.Error):
            self.prepare()

    def test_concurrent_claim_has_one_winner(self):
        def claim(_):
            try:
                self.prepare()
                return True
            except self.api.Error:
                return False
        with ThreadPoolExecutor(max_workers=2) as pool:
            self.assertEqual(sorted(pool.map(claim, range(2))), [False, True])

    def test_adapters_preview_does_not_start_models(self):
        r = self.prepare()
        for engine in ["codex", "agy", "pi"]:
            result = self.controller().run("T01", engine=engine)
            self.assertTrue(result["preview"])
            self.assertIn(engine, result["argv"])
        args = self.controller().run("T01", engine="pi", model="provider/model", provider="provider")["argv"]
        self.assertIn("--no-extensions", args)
        self.assertIn("provider/model", args)
        self.assertTrue((Path(r["worktree"]) / ".task/TASK.md").exists())

    def test_pi_host_execution_requires_explicit_acknowledgement(self):
        self.prepare()
        with self.assertRaises(self.api.Error):
            self.controller().run("T01", engine="pi", execute=True)

    def test_scope_catches_untracked_and_renamed_files(self):
        r = self.prepare()
        self.output(r)
        (Path(r["worktree"]) / "outside.txt").write_text("outside")
        with self.assertRaises(self.api.Error):
            self.controller().verify("T01")
        self.assertEqual(self.controller().records()["T01"]["status"], "ESCALATED")

    def test_rename_from_outside_scope_is_rejected(self):
        (self.root / "outside.txt").write_text("original\n")
        self.git("add", "outside.txt")
        self.git("commit", "-m", "protected source")
        r = self.prepare()
        wt = Path(r["worktree"])
        (wt / "apps/api").mkdir(parents=True)
        self.git("mv", "outside.txt", "apps/api/result.txt", cwd=wt)
        with self.assertRaises(self.api.Error):
            self.controller().verify("T01")

    def test_subprocess_preserves_literal_stdin_and_exit_status(self):
        log = self.root / "process.log"
        value = "literal $() and `backticks`"
        result = self.api.process([sys.executable, "-c", "import sys;print(sys.stdin.read());sys.exit(7)"],
                                  self.root, log, 2, value)
        self.assertEqual(result["exit_code"], 7)
        self.assertEqual(log.read_text().strip(), value)

    def test_timeout_terminates_descendants(self):
        marker = self.root / "child-survived"
        child = "import time;from pathlib import Path;time.sleep(.4);Path(" + repr(str(marker)) + ").write_text('alive')"
        parent = "import subprocess,sys,time;subprocess.Popen([sys.executable,'-c'," + repr(child) + "]);time.sleep(10)"
        result = self.api.process([sys.executable, "-c", parent], self.root, self.root / "timeout.log", .1)
        self.assertEqual(result["exit_code"], 124)
        time.sleep(.5)
        self.assertFalse(marker.exists())

    def test_failed_fake_agent_is_recorded_without_model_call(self):
        self.prepare()
        bindir = self.root / "fake-bin"
        bindir.mkdir()
        executable = bindir / "codex"
        executable.write_text("#!" + sys.executable + "\nraise SystemExit(9)\n")
        executable.chmod(0o755)
        with mock.patch.dict(os.environ, {"PATH": str(bindir) + os.pathsep + os.environ["PATH"]}):
            result = self.controller().run("T01", execute=True)
        self.assertEqual(result["exit_code"], 9)
        self.assertEqual(self.controller().records()["T01"]["status"], "FAILED")
        retry = self.prepare()
        self.assertEqual(retry["attempt"], 2)
        self.assertTrue(Path(retry["previous_attempt"]["worktree"]).exists())

    def test_quota_handoff_preserves_partial_code_and_changes_executor(self):
        r = self.prepare()
        bindir = self.root / "fake-bin"
        bindir.mkdir()
        first = bindir / "codex"
        first.write_text("#!" + sys.executable + "\nfrom pathlib import Path\np=Path('apps/api');p.mkdir(parents=True,exist_ok=True)\n(p/'partial.py').write_text('progress')\nprint('usage limit reached')\nraise SystemExit(1)\n")
        second = bindir / "agy"
        second.write_text("#!" + sys.executable + "\nfrom pathlib import Path\nassert Path('apps/api/partial.py').read_text()=='progress'\nPath('apps/api/result.txt').write_text('finished')\n")
        first.chmod(0o755)
        second.chmod(0o755)
        with mock.patch.dict(os.environ, {"PATH": str(bindir) + os.pathsep + os.environ["PATH"]}):
            result = self.controller().run_with_handoff("T01")
        self.assertEqual(result["exit_code"], 0)
        record = self.controller().records()["T01"]
        self.assertEqual(record["engine"], "agy")
        self.assertEqual(record["handoffs"][0]["from"], "codex")
        self.assertTrue((Path(r["worktree"]) / ".task/RESUME.md").exists())

    def test_handoff_does_not_transfer_out_of_scope_changes(self):
        r = self.prepare()
        (Path(r["worktree"]) / "outside.txt").write_text("unexpected")
        with self.controller().state() as records:
            records["T01"]["status"] = "FAILED"
        with self.assertRaises(self.api.Error):
            self.controller().resume_failed("T01", "agy", "quota")
        self.assertEqual(self.controller().records()["T01"]["status"], "ESCALATED")

    def test_symlink_output_is_rejected(self):
        r = self.prepare()
        p = self.output(r)
        p.unlink()
        p.symlink_to(self.root / "AGENTS.md")
        with self.assertRaises(self.api.Error):
            self.controller().verify("T01")

    def test_force_added_task_metadata_is_out_of_scope(self):
        r = self.prepare()
        self.output(r)
        self.git("add", "-f", ".task/TASK.md", cwd=Path(r["worktree"]))
        with self.assertRaises(self.api.Error):
            self.controller().verify("T01")

    def test_ignored_expected_source_is_not_valid_evidence(self):
        with (self.root / ".gitignore").open("a") as f:
            f.write("apps/api/*.txt\n")
        self.git("add", ".gitignore")
        self.git("commit", "-m", "ignored output regression")
        r = self.prepare()
        self.output(r)
        with self.assertRaises(self.api.Error):
            self.controller().verify("T01")

    def test_concurrent_verification_is_rejected(self):
        r = self.prepare()
        self.output(r)
        started, release = threading.Event(), threading.Event()

        def slow_process(argv, cwd, log, timeout_seconds, *args, **kwargs):
            if not started.is_set():
                started.set()
                release.wait(timeout=3)
            return {"argv": argv, "exit_code": 0, "log": str(log), "duration_seconds": 0}

        with mock.patch.object(self.api, "process", side_effect=slow_process):
            with ThreadPoolExecutor(max_workers=1) as pool:
                first = pool.submit(self.controller().verify, "T01")
                self.assertTrue(started.wait(timeout=2))
                try:
                    with self.assertRaises(self.api.Error):
                        self.controller().verify("T01")
                finally:
                    release.set()
                first.result(timeout=3)

    def test_missing_runtime_metadata_does_not_leave_running_claim(self):
        r = self.prepare()
        self.output(r)
        wt = Path(r["worktree"])
        (wt / ".task/TASK.md").unlink()
        (wt / ".task").rmdir()
        with self.assertRaises(self.api.Error):
            self.controller().verify("T01")
        self.assertNotEqual(self.controller().records()["T01"]["status"], "VERIFYING")

    def test_verification_failure_cannot_be_approved(self):
        t = task()
        t["verification_commands"] = [["python3", "-c", "raise SystemExit(7)"]]
        self.write_tasks([t])
        self.git("add", "orchestration/tasks.json")
        self.git("commit", "-m", "failure check")
        r = self.prepare()
        self.output(r)
        with self.assertRaises(self.api.Error):
            self.controller().verify("T01")
        with self.assertRaises(self.api.Error):
            self.controller().approve("T01")

    def test_verified_content_change_invalidates_review(self):
        r = self.prepare()
        p = self.output(r)
        self.controller().verify("T01")
        p.write_text("changed after verification\n")
        with self.assertRaises(self.api.Error):
            self.controller().review("T01", "pi-reviewer", "Evidence reviewed", "pass")

    def test_reviewer_cannot_be_claim_owner(self):
        r = self.prepare()
        self.output(r)
        self.controller().verify("T01")
        with self.assertRaises(self.api.Error):
            self.controller().review("T01", "codex-api", "self review", "pass")

    def test_merged_requires_actual_git_ancestry(self):
        r = self.prepare()
        self.output(r)
        self.controller().verify("T01")
        self.controller().review("T01", "pi-reviewer", "Reviewed authorization and tests", "pass")
        self.controller().approve("T01")
        wt = Path(r["worktree"])
        self.git("add", "apps/api/result.txt", cwd=wt)
        self.git("commit", "-m", "task result", cwd=wt)
        commit = self.git("rev-parse", "HEAD", cwd=wt).stdout.strip()
        with self.assertRaises(self.api.Error):
            self.controller().merged("T01", commit)
        self.git("merge", "--ff-only", r["branch"])
        self.controller().merged("T01", commit)
        self.assertEqual(self.controller().records()["T01"]["status"], "MERGED")


if __name__ == "__main__":
    unittest.main()
