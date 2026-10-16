import assert from "node:assert/strict";
import test from "node:test";

import { createRegistrationInviteApi } from "../src/auth/registration_api.js";

test("registration invite API requires App Check and passes caller context", async () => {
  const calls: unknown[] = [];
  const api = createRegistrationInviteApi({
    allowedOrigins: ["https://heldensync-test.web.app"],
    verifyAppCheck: async (token) => token === "valid-app-check",
    issue: async (request) => { calls.push(request); },
  });

  const missing = new FakeResponse();
  await api({
    method: "POST",
    path: "/tickets",
    headers: {},
    body: { email: "held@example.de", keyword: "secret" },
    ip: "203.0.113.1",
  }, missing);
  assert.equal(missing.statusCode, 401);

  const accepted = new FakeResponse();
  await api({
    method: "POST",
    path: "/tickets",
    headers: {
      origin: "https://heldensync-test.web.app",
      "x-firebase-appcheck": "valid-app-check",
    },
    body: { email: "held@example.de", keyword: "secret" },
    ip: "203.0.113.1",
  }, accepted);

  assert.equal(accepted.statusCode, 204);
  assert.deepEqual(calls, [{
    email: "held@example.de",
    keyword: "secret",
    callerKey: "203.0.113.1",
  }]);
});

class FakeResponse {
  statusCode = 200;
  readonly headers: Record<string, string> = {};
  body: unknown;

  status(code: number): FakeResponse {
    this.statusCode = code;
    return this;
  }

  set(name: string, value: string): FakeResponse {
    this.headers[name] = value;
    return this;
  }

  json(value: unknown): unknown {
    this.body = value;
    return value;
  }

  send(value?: unknown): unknown {
    this.body = value;
    return value;
  }
}
