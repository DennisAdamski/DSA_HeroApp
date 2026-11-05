import unittest

from tool.ci_relevant_changes import has_relevant_changes


class CiRelevantChangesTest(unittest.TestCase):
    def test_documentation_only_is_not_relevant(self) -> None:
        self.assertFalse(
            has_relevant_changes(["README.md", "docs/test_strategy.md"])
        )

    def test_code_or_workflow_change_is_relevant(self) -> None:
        self.assertTrue(has_relevant_changes(["lib/main.dart", "docs/note.md"]))
        self.assertTrue(
            has_relevant_changes([".github/workflows/flutter-tests.yml"])
        )

    def test_code_commit_followed_by_docs_commit_keeps_decisions_separate(self) -> None:
        self.assertTrue(has_relevant_changes(["lib/rules/combat.dart"]))
        self.assertFalse(has_relevant_changes(["docs/combat.md"]))


if __name__ == "__main__":
    unittest.main()
