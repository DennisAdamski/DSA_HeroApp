import assert from "node:assert/strict";
import test from "node:test";

import { formatIssue } from "../src/feedback/issue_formatter.js";
import { validateSubmission } from "../src/feedback/validation.js";

test("formats a bug with neutralized mentions and fixed labels", () => {
  const submission = validateSubmission({
    schemaVersion: 1,
    requestId: "123e4567-e89b-42d3-a456-426614174000",
    kind: "bug",
    title: "Fehler bei @admin im Kampf",
    actualBehavior: "Beim Angriff wird @admin ohne Rückfrage erwähnt.",
    expectedBehavior: "Der Angriff soll ohne externe Erwähnung abgeschlossen werden.",
    surface: "combat",
    metadata: {
      appVersion: "1.0.1",
      buildNumber: "1",
      commit: "abcdef0",
      builtAt: "2026-10-15T19:00:00Z",
      platform: "windows",
    },
  });

  const issue = formatIssue(submission, {
    marker: "feedback:marker-1",
    testMode: true,
  });

  assert.equal(issue.title, "Fehler bei @\u200badmin im Kampf");
  assert.deepEqual(issue.labels, ["in-app-feedback", "bug", "feedback-test"]);
  assert.match(issue.body, /## Tatsächliches Verhalten/);
  assert.match(issue.body, /<!-- feedback:marker-1 -->/);
  assert.doesNotMatch(issue.body, /@admin/);
});
