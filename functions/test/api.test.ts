import assert from "node:assert/strict";
import test from "node:test";

import { createFeedbackApi } from "../src/feedback/api.js";

test("rejects missing authentication and oversized bodies without calling the service", async () => {
  let calls = 0;
  const api = createFeedbackApi({
    allowedOrigins: ["https://heldensync-test.web.app"],
    verifyToken: async () => "account-a",
    submit: async () => { calls += 1; throw new Error("unexpected"); },
    status: async () => { calls += 1; throw new Error("unexpected"); },
  });

  const unauthorized = new FakeResponse();
  await api({ method: "POST", path: "/submissions", headers: {}, body: {} }, unauthorized);
  assert.equal(unauthorized.statusCode, 401);

  const oversized = new FakeResponse();
  await api({
    method: "POST",
    path: "/submissions",
    headers: { authorization: "Bearer token", "content-length": "32769" },
    body: {},
  }, oversized);
  assert.equal(oversized.statusCode, 400);
  assert.equal(calls, 0);
});

test("serves allowed preflight requests and blocks unknown browser origins", async () => {
  const api = createFeedbackApi({
    allowedOrigins: ["https://heldensync-test.web.app"],
    verifyToken: async () => "account-a",
    submit: async () => ({ requestId: "id", status: "created", issueNumber: 7 }),
    status: async () => ({ requestId: "id", status: "processing" }),
  });

  const preflight = new FakeResponse();
  await api({
    method: "OPTIONS",
    path: "/submissions",
    headers: { origin: "https://heldensync-test.web.app" },
  }, preflight);
  assert.equal(preflight.statusCode, 204);
  assert.equal(preflight.headers["access-control-allow-origin"], "https://heldensync-test.web.app");

  const blocked = new FakeResponse();
  await api({
    method: "POST",
    path: "/submissions",
    headers: {
      origin: "https://attacker.example",
      authorization: "Bearer token",
    },
    body: {},
  }, blocked);
  assert.equal(blocked.statusCode, 403);
});

test("returns created and owned status results with the documented status codes", async () => {
  const api = createFeedbackApi({
    allowedOrigins: [],
    verifyToken: async (token) => token === "good" ? "account-a" : null,
    submit: async (_uid, body) => ({
      requestId: (body as { requestId: string }).requestId,
      status: "created",
      issueNumber: 23,
      issueUrl: "https://github.test/issues/23",
    }),
    status: async (_uid, requestId) => ({ requestId, status: "uncertain" }),
  });

  const created = new FakeResponse();
  await api({
    method: "POST",
    path: "/submissions",
    headers: { authorization: "Bearer good" },
    body: { requestId: "123e4567-e89b-42d3-a456-426614174000" },
  }, created);
  assert.equal(created.statusCode, 201);
  assert.equal((created.jsonBody as { issueNumber: number }).issueNumber, 23);

  const status = new FakeResponse();
  await api({
    method: "GET",
    path: "/submissions/123e4567-e89b-42d3-a456-426614174000",
    headers: { authorization: "Bearer good" },
  }, status);
  assert.equal(status.statusCode, 202);
});

class FakeResponse {
  statusCode = 200;
  headers: Record<string, string> = {};
  jsonBody: unknown;

  status(code: number) { this.statusCode = code; return this; }
  set(name: string, value: string) { this.headers[name.toLowerCase()] = value; return this; }
  json(value: unknown) { this.jsonBody = value; return this; }
  send() { return this; }
}
