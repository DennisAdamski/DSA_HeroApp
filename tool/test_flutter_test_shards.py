import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tool" / "flutter_test_shards.py"


class FlutterTestShardsTest(unittest.TestCase):
    def test_each_test_file_is_assigned_to_exactly_one_balanced_shard(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            test_directory = root / "test"
            test_directory.mkdir()
            expected = [f"test/case_{index:02d}_test.dart" for index in range(11)]
            for relative_path in expected:
                (root / relative_path).touch()

            assignments: list[list[str]] = []
            for shard_index in range(4):
                result = subprocess.run(
                    [
                        sys.executable,
                        str(SCRIPT),
                        "--root",
                        str(root),
                        "--total-shards",
                        "4",
                        "--shard-index",
                        str(shard_index),
                    ],
                    check=False,
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                assignments.append(result.stdout.splitlines())

            flattened = [path for shard in assignments for path in shard]
            self.assertCountEqual(flattened, expected)
            self.assertEqual(len(flattened), len(set(flattened)))
            self.assertLessEqual(
                max(map(len, assignments)) - min(map(len, assignments)),
                1,
            )


if __name__ == "__main__":
    unittest.main()
