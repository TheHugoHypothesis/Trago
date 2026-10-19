"""Podman command safety without starting containers from unit tests."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest import mock


SOURCE = Path(__file__).resolve().parents[1] / "scripts/podman_env.py"
spec = importlib.util.spec_from_file_location("podman_environment", SOURCE)
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)


class PodmanPlanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="trago podman ç ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "project"
        self.root.mkdir()
        (self.root / ".git").mkdir()
        self.wt = self.root / ".worktrees/T02"
        self.wt.mkdir(parents=True)

    def test_mounts_only_workspace_profile_cache_git_and_selected_tool(self):
        with mock.patch.object(api, "installed_tools", return_value={"codex": Path("/opt/test/codex")}):
            argv = api.command(self.root, self.wt, "T02", ["codex", "--version"], "codex")
        self.assertEqual(argv[:2], ["podman", "run"])
        self.assertIn("--read-only", argv)
        self.assertIn("--interactive", argv, "Codex prompt stdin must reach the container")
        self.assertIn("--cap-drop=ALL", argv)
        self.assertIn("--security-opt=no-new-privileges", argv)
        self.assertIn(f"type=bind,src={self.root / '.git'},dst={self.root / '.git'},ro", argv)
        self.assertNotIn("--privileged", argv)
        self.assertNotIn("--network=host", argv)
        self.assertFalse(any("podman.sock" in arg for arg in argv))
        self.assertFalse((self.root / ".agent-state").exists(), "Preview must not create runtime state")

    def test_no_sdk_or_cli_mounts_for_basic_build_without_installed_tools(self):
        with mock.patch.object(api, "installed_tools", return_value={}):
            argv = api.command(self.root, self.wt, "T02", ["python3", "--version"])
        self.assertFalse(any("/opt/agents/" in arg for arg in argv))
        self.assertIn("python3", argv)

    def test_networks_and_caches_differ_by_project_and_task(self):
        self.assertNotEqual(api.namespace(self.root, "T02"), api.namespace(self.root, "T03"))
        self.assertNotEqual(api.namespace(self.root, "T02"), api.namespace(self.root / "other", "T02"))

    def test_workspace_escape_is_rejected(self):
        with self.assertRaises(ValueError):
            api.command(self.root, Path(self.temp.name), "T02", ["true"])

    def test_profile_parent_symlink_escape_is_rejected(self):
        (self.root / ".agent-state").symlink_to(Path(self.temp.name))
        with self.assertRaises(ValueError):
            api.command(self.root, self.wt, "T02", ["true"])

    def test_missing_cli_is_explicit(self):
        with mock.patch.object(api, "installed_tools", return_value={}):
            with self.assertRaises(ValueError):
                api.command(self.root, self.wt, "T02", ["agy", "--help"], "agy")


if __name__ == "__main__":
    unittest.main()
