import assert from "node:assert/strict";
import test from "node:test";

import {
  createRulesIndexApi,
  downloadUrlLifetimeSeconds,
  parseRelease,
  proofMatches,
  type RulesIndexApiDependencies,
  type RulesIndexRelease,
} from "../src/rules_index/api.js";

const proof = "a".repeat(64);
const release: RulesIndexRelease = {
  file: "index-0123456789ab.sqlite.gz",
  sha256: "b".repeat(64),
  sizeBytes: 117_000_000,
  version: "2026-10-23T12:00:00Z",
};

interface Calls {
  signed: Array<{ file: string; seconds: number }>;
  delays: number;
  latest: number;
}

function build(overrides: Partial<RulesIndexApiDependencies> = {}) {
  const calls: Calls = { signed: [], delays: 0, latest: 0 };
  const api = createRulesIndexApi({
    allowedOrigins: ["https://heldensync-test.web.app"],
    verifyAppCheck: async (token) => token === "valid-app-check",
    verifyToken: async (token) => token === "good" ? "account-a" : null,
    expectedProof: () => proof,
    latestRelease: async () => { calls.latest += 1; return release; },
    signDownloadUrl: async (file, seconds) => {
      calls.signed.push({ file, seconds });
      return `https://storage.test/${file}?sig=x`;
    },
    delayAfterFailure: async () => { calls.delays += 1; },
    ...overrides,
  });
  return { api, calls };
}

function request(options: {
  headers?: Record<string, string>;
  body?: unknown;
  method?: string;
} = {}) {
  return {
    method: options.method ?? "POST",
    path: "/",
    headers: {
      authorization: "Bearer good",
      "x-firebase-appcheck": "valid-app-check",
      ...options.headers,
    },
    body: "body" in options ? options.body : { proof },
  };
}

test("liefert bei Konto, App Check und Nachweis eine kurzlebige URL", async () => {
  const { api, calls } = build();
  const response = new FakeResponse();
  await api(request(), response);

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body, {
    url: "https://storage.test/index-0123456789ab.sqlite.gz?sig=x",
    version: release.version,
    sha256: release.sha256,
    sizeBytes: release.sizeBytes,
    expiresInSeconds: downloadUrlLifetimeSeconds,
  });
  assert.deepEqual(calls.signed, [
    { file: release.file, seconds: downloadUrlLifetimeSeconds },
  ]);
});

test("ohne App Check oder Konto wird nichts gelesen oder signiert", async () => {
  const { api, calls } = build();

  const keinAppCheck = new FakeResponse();
  await api(request({ headers: { "x-firebase-appcheck": "" } }), keinAppCheck);
  assert.equal(keinAppCheck.statusCode, 401);
  assert.equal(keinAppCheck.body.code, "APP_CHECK_REQUIRED");

  const falschesAppCheck = new FakeResponse();
  await api(request({ headers: { "x-firebase-appcheck": "kaputt" } }), falschesAppCheck);
  assert.equal(falschesAppCheck.body.code, "APP_CHECK_INVALID");

  const keinKonto = new FakeResponse();
  await api(request({ headers: { authorization: "" } }), keinKonto);
  assert.equal(keinKonto.body.code, "AUTH_REQUIRED");

  const falschesKonto = new FakeResponse();
  await api(request({ headers: { authorization: "Bearer schlecht" } }), falschesKonto);
  assert.equal(falschesKonto.body.code, "AUTH_INVALID");

  assert.equal(calls.latest, 0);
  assert.deepEqual(calls.signed, []);
});

test("ein falscher Nachweis wird abgelehnt, gebremst und nie signiert", async () => {
  const { api, calls } = build();
  const response = new FakeResponse();
  await api(request({ body: { proof: "c".repeat(64) } }), response);

  assert.equal(response.statusCode, 403);
  assert.equal(response.body.code, "PROOF_INVALID");
  assert.equal(calls.delays, 1);
  assert.equal(calls.latest, 0);
  assert.deepEqual(calls.signed, []);
});

test("ein fehlender oder unförmiger Nachweis ist ein Fehler der Anfrage", async () => {
  const { api, calls } = build();
  for (const body of [undefined, {}, { proof: 7 }, { proof: "zz" }, { proof: "A".repeat(64) }]) {
    const response = new FakeResponse();
    await api(request({ body }), response);
    assert.equal(response.statusCode, 400, JSON.stringify(body));
    assert.equal(response.body.code, "INVALID_PAYLOAD");
  }
  assert.equal(calls.delays, 0);
});

test("ohne eingerichteten Nachweis des Servers gibt es nie Zugang", async () => {
  const { api } = build({ expectedProof: () => "" });
  const response = new FakeResponse();
  await api(request(), response);
  assert.equal(response.statusCode, 403);
});

test("ohne Veröffentlichung oder mit unsicherem Dateinamen: NO_RELEASE", async () => {
  for (const latest of [
    async () => null,
    async () => ({ ...release, file: "../geheim.sqlite" }),
  ]) {
    const { api, calls } = build({ latestRelease: latest });
    const response = new FakeResponse();
    await api(request(), response);
    assert.equal(response.statusCode, 404);
    assert.equal(response.body.code, "NO_RELEASE");
    assert.deepEqual(calls.signed, []);
  }
});

test("Fehler beim Signieren melden 503 ohne Einzelheiten", async () => {
  const { api } = build({
    signDownloadUrl: async () => { throw new Error("iam.serviceAccounts.signBlob denied"); },
  });
  const response = new FakeResponse();
  await api(request(), response);
  assert.equal(response.statusCode, 503);
  assert.deepEqual(response.body, { code: "SERVICE_UNAVAILABLE" });
});

test("nur POST, Vorabfrage nur für erlaubte Ursprünge", async () => {
  const { api } = build();

  const get = new FakeResponse();
  await api(request({ method: "GET" }), get);
  assert.equal(get.statusCode, 405);

  const preflight = new FakeResponse();
  await api({
    method: "OPTIONS",
    path: "/",
    headers: { origin: "https://heldensync-test.web.app" },
  }, preflight);
  assert.equal(preflight.statusCode, 204);
  assert.equal(preflight.headers["access-control-allow-origin"], "https://heldensync-test.web.app");

  const fremd = new FakeResponse();
  await api(request({ headers: { origin: "https://attacker.example" } }), fremd);
  assert.equal(fremd.statusCode, 403);
});

test("zu große Anfragen werden vor jeder Prüfung abgewiesen", async () => {
  const { api, calls } = build();
  const response = new FakeResponse();
  await api(request({ headers: { "content-length": "2048" } }), response);
  assert.equal(response.statusCode, 400);
  assert.equal(calls.latest, 0);
});

test("proofMatches vergleicht nur gleich lange, gültige hex-Nachweise", () => {
  assert.equal(proofMatches(proof, proof), true);
  assert.equal(proofMatches(proof, "b".repeat(64)), false);
  assert.equal(proofMatches("abc", "abc"), false);
  assert.equal(proofMatches(proof, ""), false);
});

test("parseRelease nimmt nur vollständige, sichere Beschreibungen an", () => {
  assert.deepEqual(parseRelease(release), release);
  assert.equal(parseRelease(null), null);
  assert.equal(parseRelease({ ...release, file: "index-xyz.sqlite.gz" }), null);
  assert.equal(parseRelease({ ...release, sha256: "kurz" }), null);
  assert.equal(parseRelease({ ...release, sizeBytes: 0 }), null);
  assert.equal(parseRelease({ ...release, version: "" }), null);
});

class FakeResponse {
  statusCode = 200;
  headers: Record<string, string> = {};
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  body: any;

  status(code: number): this { this.statusCode = code; return this; }
  set(name: string, value: string): this { this.headers[name.toLowerCase()] = value; return this; }
  json(value: unknown): unknown { this.body = value; return value; }
  send(value?: unknown): unknown { this.body = value; return value; }
}
