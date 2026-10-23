import json
import tempfile
import unittest
from pathlib import Path

from tool.check_rule_test_evidence import validate_inventory


class RuleTestEvidenceValidationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        (self.root / "test" / "rules").mkdir(parents=True)
        (self.root / "test" / "catalog").mkdir(parents=True)
        (self.root / "test" / "rules" / "sample_test.dart").write_text(
            "void main() {}\n",
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def _write_inventory(self, entry: dict | None) -> Path:
        files = {} if entry is None else {"test/rules/sample_test.dart": entry}
        path = self.root / "tool" / "rule_test_evidence.json"
        path.parent.mkdir()
        path.write_text(
            json.dumps({"schemaVersion": 1, "files": files}),
            encoding="utf-8",
        )
        return path

    def test_missing_entry_is_rejected(self) -> None:
        errors = validate_inventory(self.root, self._write_inventory(None))
        self.assertTrue(any("nicht inventarisiert" in error for error in errors))

    def test_unknown_kind_is_rejected(self) -> None:
        errors = validate_inventory(
            self.root,
            self._write_inventory(
                {
                    "kind": "guess",
                    "status": "verified",
                    "summary": "Beispiel",
                    "sources": [],
                }
            ),
        )
        self.assertTrue(any("ungültige Art" in error for error in errors))

    def test_verified_official_rule_requires_complete_source(self) -> None:
        errors = validate_inventory(
            self.root,
            self._write_inventory(
                {
                    "kind": "official",
                    "status": "verified",
                    "summary": "Beispiel",
                    "sources": [{"title": "WdS", "pages": "83"}],
                }
            ),
        )
        self.assertTrue(any("mcpChunks" in error for error in errors))

    def test_stale_entry_is_rejected(self) -> None:
        path = self._write_inventory(
            {
                "kind": "product_contract",
                "status": "verified",
                "summary": "Beispiel",
                "sources": [],
            }
        )
        payload = json.loads(path.read_text(encoding="utf-8"))
        payload["files"]["test/rules/removed_test.dart"] = payload["files"].pop(
            "test/rules/sample_test.dart"
        )
        path.write_text(json.dumps(payload), encoding="utf-8")

        errors = validate_inventory(self.root, path)
        self.assertTrue(any("veralteter Pfad" in error for error in errors))

    def test_documented_conflict_is_accepted(self) -> None:
        errors = validate_inventory(
            self.root,
            self._write_inventory(
                {
                    "kind": "official",
                    "status": "conflict",
                    "summary": "Beispiel",
                    "sources": [],
                    "finding": "Der vollständige Quellenbeleg fehlt.",
                    "followUp": "RULE-AUDIT-EXAMPLE",
                }
            ),
        )
        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
