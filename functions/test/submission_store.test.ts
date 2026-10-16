import assert from "node:assert/strict";
import test from "node:test";

import type { Firestore } from "firebase-admin/firestore";

import {
  FirestoreFeedbackSubmissionStore,
  nextRateLimit,
} from "../src/feedback/submission_store.js";
import { validateSubmission } from "../src/feedback/validation.js";

test("allows three hourly and ten daily submissions, then rejects the next one", () => {
  const now = new Date("2026-10-15T20:00:00Z");
  const twoRecent = [
    new Date("2026-10-15T19:10:00Z"),
    new Date("2026-10-15T19:50:00Z"),
  ];
  const accepted = nextRateLimit(twoRecent, now);
  assert.equal(accepted.length, 3);
  assert.throws(() => nextRateLimit(accepted, now), /RATE_LIMITED/);

  const daily = Array.from({ length: 10 }, (_, index) =>
    new Date(Date.parse("2026-10-15T09:00:00Z") + index * 30 * 60 * 1000));
  assert.throws(() => nextRateLimit(daily, now), /RATE_LIMITED/);
});

test("drops timestamps outside the rolling day before adding the new claim", () => {
  const now = new Date("2026-10-15T20:00:00Z");
  const result = nextRateLimit([
    new Date("2026-10-14T19:59:59Z"),
    new Date("2026-10-15T10:00:00Z"),
  ], now);
  assert.deepEqual(
    result.map((value) => value.toISOString()),
    ["2026-10-15T10:00:00.000Z", "2026-10-15T20:00:00.000Z"],
  );
});

test("sets feedback metadata expiry to seven days after the claim", async () => {
  const now = new Date("2026-10-16T12:00:00Z");
  const writes: Array<Record<string, unknown>> = [];
  const firestore = {
    collection: () => ({ doc: () => ({}) }),
    runTransaction: async (operation: (transaction: never) => unknown) =>
      operation({
        get: async () => ({ exists: false, data: () => undefined }),
        set: (_reference: unknown, value: Record<string, unknown>) => writes.push(value),
        create: (_reference: unknown, value: Record<string, unknown>) => writes.push(value),
      } as never),
  } as unknown as Firestore;
  const store = new FirestoreFeedbackSubmissionStore(firestore);
  const submission = validateSubmission({
    schemaVersion: 1,
    requestId: "123e4567-e89b-42d3-a456-426614174000",
    kind: "feature",
    title: "Wiederkehrende Gegner speichern",
    problem: "Wiederkehrende Gegner müssen jedes Mal neu erfasst werden.",
    desiredBehavior: "Gegner sollen als Vorlage gespeichert werden können.",
    surface: "combat",
    metadata: {
      appVersion: "1.0.1",
      buildNumber: "1",
      commit: "abcdef0",
      builtAt: "2026-10-15T19:00:00Z",
      platform: "windows",
    },
  });

  const claim = await store.claim("account-a", submission, "hash", "marker", now);

  assert.equal(claim.isNew, true);
  assert.deepEqual(
    writes.map((value) => (value.expiresAt as Date).toISOString()),
    ["2026-10-23T12:00:00.000Z", "2026-10-23T12:00:00.000Z"],
  );
});
