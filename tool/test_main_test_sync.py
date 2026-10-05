"""Exercise main-to-test merges against disposable Git repositories."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("sync_main_to_test.sh").resolve()
BASH = str(Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe") if os.name == "nt" else shutil.which("bash")


class SyncTests(unittest.TestCase):
    """Pin preservation, conflict handling and idempotency without a cloud repo."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.remote = self.root / "remote.git"
        self.writer = self.root / "writer"
        self.git(self.root, "init", "--bare", str(self.remote))
        self.git(self.root, "init", "-b", "main", str(self.writer))
        self.git(self.writer, "config", "user.name", "Fixture")
        self.git(self.writer, "config", "user.email", "fixture@example.invalid")
        self.commit("shared.txt", "base", "initial")
        self.git(self.writer, "remote", "add", "origin", str(self.remote))
        self.git(self.writer, "branch", "test")
        self.git(self.writer, "push", "origin", "main", "test")
        self.clone = self.root / "runner"
        self.git(self.root, "clone", "--branch", "main", str(self.remote), str(self.clone))
        self.output = self.root / "output"

    def git(self, cwd, *args):
        result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout.strip()

    def commit(self, name, content, message):
        (self.writer / name).write_text(content, encoding="utf-8")
        self.git(self.writer, "add", name)
        self.git(self.writer, "commit", "-m", message)

    def run_sync(self):
        self.output.write_text("", encoding="utf-8")
        env = dict(os.environ, GITHUB_OUTPUT=str(self.output))
        return subprocess.run([BASH, str(SCRIPT)], cwd=self.clone, env=env, capture_output=True, text=True, encoding="utf-8")

    def test_main_only_change_and_second_run_is_noop(self):
        self.commit("main.txt", "main change", "main update")
        self.git(self.writer, "push", "origin", "main")
        result = self.run_sync()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("changed=true", self.output.read_text())
        main_sha = self.git(self.remote, "rev-parse", "main")
        self.assertEqual(main_sha, self.git(self.remote, "rev-parse", "test"))
        result = self.run_sync()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("changed=false", self.output.read_text())

    def test_test_only_changes_survive_merge(self):
        self.git(self.writer, "switch", "test")
        self.commit("test.txt", "test change", "test update")
        self.git(self.writer, "push", "origin", "test")
        self.git(self.writer, "switch", "main")
        self.commit("main.txt", "main change", "main update")
        self.git(self.writer, "push", "origin", "main")
        result = self.run_sync()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.git(self.remote, "show", "test:test.txt"), "test change")
        self.assertEqual(self.git(self.remote, "show", "test:main.txt"), "main change")
        sha = self.git(self.remote, "rev-parse", "test")
        self.assertIn("sha=" + sha, self.output.read_text())

    def test_conflict_leaves_remote_test_unchanged(self):
        self.git(self.writer, "switch", "test")
        self.commit("shared.txt", "test edit", "test update")
        self.git(self.writer, "push", "origin", "test")
        before = self.git(self.remote, "rev-parse", "test")
        self.git(self.writer, "switch", "main")
        self.commit("shared.txt", "main edit", "main update")
        self.git(self.writer, "push", "origin", "main")
        result = self.run_sync()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("::error::Merge conflict", result.stdout)
        self.assertEqual(before, self.git(self.remote, "rev-parse", "test"))
        self.assertNotIn("changed=true", self.output.read_text())

    def test_rejected_push_stops_after_three_attempts(self):
        self.commit("main.txt", "main change", "main update")
        self.git(self.writer, "push", "origin", "main")
        hook = self.remote / "hooks/pre-receive"
        hook.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
        hook.chmod(0o755)
        before = self.git(self.remote, "rev-parse", "test")
        result = self.run_sync()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("after three attempts", result.stdout)
        self.assertEqual(result.stdout.count("Remote test changed"), 3)
        self.assertEqual(before, self.git(self.remote, "rev-parse", "test"))


if __name__ == "__main__":
    unittest.main()
