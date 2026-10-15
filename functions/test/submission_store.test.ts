import assert from "node:assert/strict";
import test from "node:test";

import { nextRateLimit } from "../src/feedback/submission_store.js";

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
