import assert from "node:assert/strict";
import test from "node:test";

import {
  RegistrationInviteService,
  RegistrationServiceError,
  type RegistrationTicketStore,
} from "../src/auth/registration_service.js";

test("issues a normalized short-lived email-bound ticket", async () => {
  const store = new MemoryRegistrationStore();
  const service = new RegistrationInviteService(store, {
    verifyKeyword: async (keyword) => keyword === "correct horse battery staple",
    ticketTtlMs: 10 * 60 * 1000,
  });
  const now = new Date("2026-10-17T10:00:00Z");

  await service.issue({
    email: "  Held@Example.DE ",
    keyword: "correct horse battery staple",
    callerKey: "client-a",
    now,
  });

  assert.deepEqual(store.tickets.get("held@example.de"), {
    expiresAt: new Date("2026-10-17T10:10:00Z"),
    used: false,
  });
});

test("rejects invalid keyword and rate-limits repeated attempts", async () => {
  const store = new MemoryRegistrationStore();
  const service = new RegistrationInviteService(store, {
    verifyKeyword: async () => false,
    maxAttempts: 2,
  });
  const request = {
    email: "held@example.de",
    keyword: "wrong",
    callerKey: "client-a",
    now: new Date("2026-10-17T10:00:00Z"),
  };

  await assert.rejects(service.issue(request), hasCode("INVITE_INVALID"));
  await assert.rejects(service.issue(request), hasCode("INVITE_INVALID"));
  await assert.rejects(service.issue(request), hasCode("RATE_LIMITED"));
});

test("ticket consumption is single-use and rejects expired tickets", async () => {
  const store = new MemoryRegistrationStore();
  const service = new RegistrationInviteService(store, {
    verifyKeyword: async () => true,
    ticketTtlMs: 1000,
  });
  const now = new Date("2026-10-17T10:00:00Z");
  await service.issue({
    email: "held@example.de",
    keyword: "secret",
    callerKey: "client-a",
    now,
  });

  assert.equal(await service.consume("held@example.de", now), true);
  assert.equal(await service.consume("held@example.de", now), false);

  await service.issue({
    email: "other@example.de",
    keyword: "secret",
    callerKey: "client-b",
    now,
  });
  const expired = new Date(now.getTime() + 1001);
  assert.equal(await service.consume("other@example.de", expired), false);
});

function hasCode(code: string) {
  return (error: unknown) => {
    assert.ok(error instanceof RegistrationServiceError);
    assert.equal(error.code, code);
    return true;
  };
}

class MemoryRegistrationStore implements RegistrationTicketStore {
  readonly attempts = new Map<string, number>();
  readonly tickets = new Map<string, { expiresAt: Date; used: boolean }>();

  async allowAttempt(key: string, maxAttempts: number): Promise<boolean> {
    const count = this.attempts.get(key) ?? 0;
    if (count >= maxAttempts) return false;
    this.attempts.set(key, count + 1);
    return true;
  }

  async issueTicket(email: string, expiresAt: Date): Promise<void> {
    this.tickets.set(email, { expiresAt, used: false });
  }

  async consumeTicket(email: string, now: Date): Promise<boolean> {
    const ticket = this.tickets.get(email);
    if (ticket == null || ticket.used || ticket.expiresAt <= now) return false;
    ticket.used = true;
    return true;
  }
}
