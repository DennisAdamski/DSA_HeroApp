import assert from "node:assert/strict";
import test from "node:test";

import { validateSubmission } from "../src/feedback/validation.js";

const base = {
  schemaVersion: 1,
  requestId: "123e4567-e89b-42d3-a456-426614174000",
  title: "Beschwörung bricht ab",
  surface: "magic",
  metadata: {
    appVersion: "1.0.1",
    buildNumber: "1",
    commit: "abcdef0",
    builtAt: "2026-10-15T19:00:00Z",
    platform: "windows",
  },
};

test("validates each typed submission without accepting another kind's fields", () => {
  const bug = validateSubmission({
    ...base,
    kind: "bug",
    actualBehavior: "Der Dialog schließt sich ohne Ergebnis.",
    expectedBehavior: "Der Dialog zeigt das Ergebnis der Probe.",
    reproductionSteps: "Magie öffnen und den Zauber auslösen.",
  });
  assert.equal(bug.kind, "bug");

  const feature = validateSubmission({
    ...base,
    kind: "feature",
    problem: "Wiederkehrende Gegner müssen jedes Mal neu erfasst werden.",
    desiredBehavior: "Gegner sollen als Vorlage gespeichert werden können.",
  });
  assert.equal(feature.kind, "feature");

  assert.throws(
    () => validateSubmission({ ...feature, actualBehavior: "unerlaubt" }),
    /Unbekanntes Feld/,
  );

  const rules = validateSubmission({
    ...base,
    kind: "rules",
    question: "Welche Erschwernis gilt in dieser kombinierten Situation?",
    source: "WdS, Seite 42",
    interpretation: "Ich würde beide Modifikatoren addieren.",
  });
  assert.equal(rules.kind, "rules");
});

test("rejects malformed identifiers, short text, oversized sources and unknown surfaces", () => {
  assert.throws(
    () => validateSubmission({
      ...base,
      requestId: "not-a-uuid",
      kind: "bug",
      actualBehavior: "zu kurz",
      expectedBehavior: "ebenfalls zu kurz",
    }),
    /requestId/,
  );

  assert.throws(
    () => validateSubmission({
      ...base,
      surface: "hero-42",
      kind: "rules",
      question: "Welche Regel gilt in dieser konkreten Spielsituation?",
    }),
    /surface/,
  );

  assert.throws(
    () => validateSubmission({
      ...base,
      kind: "rules",
      question: "Welche Regel gilt in dieser konkreten Spielsituation?",
      source: "x".repeat(301),
    }),
    /source/,
  );
});

test("accepts a complete bug diagnostic package but no identity fields", () => {
  const payload = validateSubmission({
    ...base,
    kind: "bug",
    actualBehavior: "Die Tabelle läuft am rechten Rand aus dem Fenster.",
    expectedBehavior: "Die Tabelle bleibt vollständig horizontal erreichbar.",
    diagnostics: {
      operatingSystem: "Windows",
      operatingSystemVersion: "11 24H2",
      locale: "de-DE",
      viewportWidth: 1280,
      viewportHeight: 720,
      devicePixelRatio: 1.25,
      layoutClass: "desktopWide",
      interfaceVariant: "kartograph",
      brightness: "dark",
      tableMode: "automatic",
      firebaseAvailable: true,
      authenticated: true,
    },
  });
  assert.equal(payload.kind, "bug");

  assert.throws(
    () => validateSubmission({
      ...payload,
      diagnostics: { ...payload.diagnostics, email: "person@example.test" },
    }),
    /Unbekanntes Feld/,
  );
});
