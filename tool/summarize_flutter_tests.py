#!/usr/bin/env python3
"""Erzeugt aus dem JSON-Reporter eine kompakte CI-Laufzeitübersicht."""

from __future__ import annotations

import argparse
import json
import os
from collections import defaultdict
from pathlib import Path
from typing import Any


def _events(path: Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(event, dict):
            events.append(event)
    return events


def summarize_report(path: Path, *, shard_label: str) -> str:
    """Fasst Ergebnis, Gesamtdauer und langsame Testdateien zusammen."""

    suites: dict[int, str] = {}
    tests: dict[int, tuple[int, int]] = {}
    suite_durations: defaultdict[str, int] = defaultdict(int)
    counts: defaultdict[str, int] = defaultdict(int)
    total_ms = 0

    for event in _events(path):
        event_type = event.get("type")
        if event_type == "suite":
            suite = event.get("suite", {})
            suites[suite.get("id")] = suite.get("path", "unbekannte Suite")
        elif event_type == "testStart":
            test = event.get("test", {})
            tests[test.get("id")] = (test.get("suiteID"), event.get("time", 0))
        elif event_type == "testDone" and not event.get("hidden", False):
            test_id = event.get("testID")
            if test_id in tests:
                suite_id, started_ms = tests[test_id]
                suite_durations[suites.get(suite_id, "unbekannte Suite")] += max(
                    0, event.get("time", 0) - started_ms
                )
            counts[event.get("result", "unknown")] += 1
        elif event_type == "done":
            total_ms = event.get("time", total_ms)

    lines = [
        f"### Flutter-Tests — Shard {shard_label}",
        "",
        (
            f"{counts['success']} erfolgreich, {counts['failure'] + counts['error']} "
            f"fehlgeschlagen, {counts['skipped']} übersprungen; "
            f"Gesamtdauer {total_ms / 1000:.2f} s."
        ),
        "",
        "| Langsamste Datei | kumulierte Testzeit |",
        "| --- | ---: |",
    ]
    for suite, duration_ms in sorted(
        suite_durations.items(), key=lambda item: item[1], reverse=True
    )[:10]:
        lines.append(f"| `{suite}` | {duration_ms / 1000:.2f} s |")
    return "\n".join(lines) + "\n"


def main() -> int:
    """Schreibt die Zusammenfassung auf stdout und optional ins Job-Summary."""

    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("--shard", required=True)
    args = parser.parse_args()
    summary = summarize_report(args.report, shard_label=args.shard)
    print(summary, end="")
    job_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if job_summary:
        with Path(job_summary).open("a", encoding="utf-8") as output:
            output.write(summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
