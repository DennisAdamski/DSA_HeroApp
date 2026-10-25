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
        path.parent.mkdir(exist_ok=True)
        path.write_text(
            json.dumps({"schemaVersion": 1, "files": files}),
            encoding="utf-8",
        )
        return path

    def test_missing_entry_is_rejected(self) -> None:
        errors = validate_inventory(self.root, self._write_inventory(None))
        self.assertTrue(any("nicht inventarisiert" in error for error in errors))

    def test_extracted_case_file_must_be_inventoried(self) -> None:
        (self.root / "test" / "rules" / "sample_cases.dart").write_text(
            "part of 'sample_test.dart';\n",
            encoding="utf-8",
        )
        errors = validate_inventory(
            self.root,
            self._write_inventory(
                {
                    "kind": "product_contract",
                    "status": "verified",
                    "summary": "Beispiel",
                    "sources": [],
                }
            ),
        )
        self.assertTrue(
            any("sample_cases.dart" in error for error in errors),
            errors,
        )

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

    def _conflict_item(self, **overrides: object) -> dict:
        item: dict = {
            "conflictKey": "beispiel-tp",
            "conflictType": "contradiction",
            "finding": "Der Test erwartet +2, das Buch nennt +3.",
            "testCases": ["Beispiel gibt +2"],
            "expected": "+2",
            "bookRule": [
                {
                    "title": "Wege des Schwerts",
                    "pages": "83",
                    "mcpChunks": [7048],
                    "checkedOn": "2026-10-24",
                }
            ],
            "deviation": "Differenz von einem Punkt.",
            "impact": "Vorschau zeigt zu wenig Schaden.",
            "priority": "P2",
            "followUp": "RULE-FIX-001",
        }
        item.update(overrides)
        return item

    def _conflict(self, **overrides: object) -> dict:
        return {
            "kind": "official",
            "status": "conflict",
            "summary": "Beispiel für einen belegten Widerspruch",
            "sources": [],
            "conflicts": [self._conflict_item(**overrides)],
        }

    def test_documented_conflict_is_accepted(self) -> None:
        errors = validate_inventory(
            self.root, self._write_inventory(self._conflict())
        )
        self.assertEqual(errors, [])

    def test_bundled_follow_up_is_rejected(self) -> None:
        errors = validate_inventory(
            self.root,
            self._write_inventory(self._conflict(followUp="RULE-AUDIT-MAGIC")),
        )
        self.assertTrue(any("RULE-FIX-NNN" in error for error in errors))

    def test_blanket_placeholder_finding_is_rejected(self) -> None:
        errors = validate_inventory(
            self.root,
            self._write_inventory(
                self._conflict(
                    finding="Der Inhalt ist noch nicht vollständig geprüft."
                )
            ),
        )
        self.assertTrue(any("Platzhalter" in error for error in errors))

    def test_conflict_requires_concrete_evidence_fields(self) -> None:
        entry = self._conflict()
        for key in ("testCases", "expected", "deviation", "impact", "priority"):
            del entry["conflicts"][0][key]
        errors = validate_inventory(self.root, self._write_inventory(entry))
        for key in ("testCases", "expected", "deviation", "impact", "priority"):
            self.assertTrue(any(key in error for error in errors), (key, errors))

    def test_contradiction_requires_complete_book_rule(self) -> None:
        errors = validate_inventory(
            self.root,
            self._write_inventory(
                self._conflict(bookRule=[{"title": "Wege des Schwerts"}])
            ),
        )
        self.assertTrue(any("bookRule" in error for error in errors))

    def test_source_gap_requires_searched_terms(self) -> None:
        gap = self._conflict(conflictType="source_gap", bookRule=[])
        errors = validate_inventory(self.root, self._write_inventory(gap))
        self.assertTrue(any("searchedTerms" in error for error in errors))

        gap["conflicts"][0]["searchedTerms"] = ["Beispielbegriff"]
        errors = validate_inventory(self.root, self._write_inventory(gap))
        self.assertEqual(errors, [])

    def test_product_contract_requires_rationale(self) -> None:
        entry = {
            "kind": "product_contract",
            "status": "verified",
            "summary": "Prüft die Serialisierung von Beispieldaten.",
            "sources": [],
        }
        errors = validate_inventory(self.root, self._write_inventory(entry))
        self.assertTrue(any("rationale" in error for error in errors))

        entry["rationale"] = "Keine DSA-Regelaussage, nur Serialisierung."
        errors = validate_inventory(self.root, self._write_inventory(entry))
        self.assertEqual(errors, [])

    def test_filename_placeholder_summary_is_rejected(self) -> None:
        entry = {
            "kind": "product_contract",
            "status": "verified",
            "summary": "Technischer Katalogvertrag: sample",
            "rationale": "Begründung",
            "sources": [],
        }
        errors = validate_inventory(self.root, self._write_inventory(entry))
        self.assertTrue(any("summary ist ein Platzhalter" in e for e in errors))

    def test_check_date_must_be_iso(self) -> None:
        entry = {
            "kind": "official",
            "status": "verified",
            "summary": "Beispielregel",
            "sources": [
                {
                    "title": "Wege des Schwerts",
                    "pages": "83",
                    "mcpChunks": [7048],
                    "checkedOn": "24.10.2026",
                }
            ],
        }
        errors = validate_inventory(self.root, self._write_inventory(entry))
        self.assertTrue(any("YYYY-MM-DD" in error for error in errors))

    def test_follow_up_must_not_cover_different_conflicts(self) -> None:
        (self.root / "test" / "rules" / "other_test.dart").write_text(
            "void main() {}\n", encoding="utf-8"
        )
        path = self._write_inventory(self._conflict())
        payload = json.loads(path.read_text(encoding="utf-8"))
        payload["files"]["test/rules/other_test.dart"] = self._conflict(
            conflictKey="anderer-konflikt"
        )
        path.write_text(json.dumps(payload), encoding="utf-8")
        errors = validate_inventory(self.root, path)
        self.assertTrue(any("verschiedenen" in error for error in errors))

        payload["files"]["test/rules/other_test.dart"] = self._conflict()
        path.write_text(json.dumps(payload), encoding="utf-8")
        self.assertEqual(validate_inventory(self.root, path), [])

    def test_conflict_requires_conflict_list(self) -> None:
        entry = self._conflict()
        entry["conflicts"] = []
        errors = validate_inventory(self.root, self._write_inventory(entry))
        self.assertTrue(any("conflicts" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
