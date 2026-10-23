import json
import tempfile
import unittest
from pathlib import Path

from tool.summarize_flutter_tests import summarize_report


class FlutterTestReportSummaryTest(unittest.TestCase):
    def test_reports_counts_duration_and_slowest_suite(self) -> None:
        events = [
            {"type": "suite", "time": 0, "suite": {"id": 1, "path": "test/a_test.dart"}},
            {
                "type": "testStart",
                "time": 10,
                "test": {"id": 2, "suiteID": 1, "name": "a"},
            },
            {"type": "testDone", "time": 2010, "testID": 2, "result": "success"},
            {"type": "done", "time": 2100, "success": True},
        ]
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "report.json"
            report.write_text(
                "\n".join(json.dumps(event) for event in events),
                encoding="utf-8",
            )

            summary = summarize_report(report, shard_label="2/4")

        self.assertIn("Shard 2/4", summary)
        self.assertIn("1 erfolgreich", summary)
        self.assertIn("2.10 s", summary)
        self.assertIn("test/a_test.dart", summary)
        self.assertIn("2.00 s", summary)


if __name__ == "__main__":
    unittest.main()
