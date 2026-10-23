#!/usr/bin/env python3
"""Regressionstests fuer die parallelisierte Flutter-CI."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "flutter-tests.yml"


class FlutterCiStructureTest(unittest.TestCase):
    def setUp(self) -> None:
        self.workflow = WORKFLOW.read_text(encoding="utf-8")

    def test_four_native_flutter_shards_are_configured(self) -> None:
        indices = re.findall(r"^\s+- index: (\d+)$", self.workflow, re.MULTILINE)
        self.assertEqual(["0", "1", "2", "3"], indices)
        self.assertIn("--total-shards 4", self.workflow)
        self.assertIn("--shard-index ${{ matrix.shard.index }}", self.workflow)
        self.assertIn("fail-fast: false", self.workflow)

    def test_tests_do_not_wait_for_analysis_and_stable_gate_remains(self) -> None:
        shard_block = self.workflow.split("  test-shard:", 1)[1].split(
            "\n  test:", 1
        )[0]
        self.assertNotIn("needs: analyze", shard_block)
        gate_block = self.workflow.split("\n  test:", 1)[1].split(
            "\n  loc-budget:", 1
        )[0]
        self.assertIn("name: Unit- & Widget-Tests", gate_block)
        self.assertIn("needs: test-shard", gate_block)

    def test_reports_inventory_and_docs_only_filter_are_present(self) -> None:
        self.assertIn("--file-reporter", self.workflow)
        self.assertIn("tool/summarize_flutter_tests.py", self.workflow)
        self.assertIn("python tool/check_rule_test_evidence.py", self.workflow)
        self.assertGreaterEqual(self.workflow.count("paths-ignore:"), 2)


if __name__ == "__main__":
    unittest.main()
