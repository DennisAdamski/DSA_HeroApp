import { timingSafeEqual } from "node:crypto";

/** Beschreibung der veröffentlichten Regel-Wissensbasis (`rules/latest.json`). */
export interface RulesIndexRelease {
  /** Dateiname unter `rules/`, enthält die Kurzprüfsumme. */
  file: string;
  /** SHA-256 der **entpackten** SQLite-Datei (hex). */
  sha256: string;
  /** Größe der entpackten Datei in Byte. */
  sizeBytes: number;
  /** Veröffentlichungszeitpunkt (ISO 8601), dient der Versionsanzeige. */
  version: string;
}

export interface RulesIndexHttpRequest {
  method: string;
  path: string;
  headers: Record<string, string | string[] | undefined>;
  body?: unknown;
}

export interface RulesIndexHttpResponse {
  status(code: number): RulesIndexHttpResponse;
  set(name: string, value: string): RulesIndexHttpResponse;
  json(value: unknown): unknown;
  send(value?: unknown): unknown;
}

export interface RulesIndexApiDependencies {
  allowedOrigins: Array<string | RegExp>;
  verifyAppCheck(token: string): Promise<boolean>;
  /** Liefert die UID eines bestätigten Kontos oder `null`. */
  verifyToken(token: string): Promise<string | null>;
  /** Erwarteter Passwortnachweis (hex), siehe `tool/rules_index_proof.py`. */
  expectedProof(): string;
  /** Aktuelle Veröffentlichung oder `null`, wenn noch keine existiert. */
  latestRelease(): Promise<RulesIndexRelease | null>;
  /** Erzeugt eine kurzlebige Download-URL für die Datei. */
  signDownloadUrl(file: string, expiresInSeconds: number): Promise<string>;
  /** Bremst falsche Nachweise aus; in Tests ersetzbar. */
  delayAfterFailure?(): Promise<void>;
}

/** Gültigkeit der Download-URL in Sekunden. */
export const downloadUrlLifetimeSeconds = 600;

const releaseFilePattern = /^index-[0-9a-f]{12}\.sqlite\.gz$/;
const proofPattern = /^[0-9a-f]{64}$/;

/**
 * Baut die HTTP-Grenze um den Zugang zur Regel-Wissensbasis.
 *
 * Wer ein bestätigtes Konto, ein gültiges App-Check-Token **und** den
 * Passwortnachweis des Katalogs mitbringt, bekommt eine kurzlebige URL auf die
 * (für Clients nicht lesbare) Datei. Die Datei selbst liegt nie offen.
 */
export function createRulesIndexApi(dependencies: RulesIndexApiDependencies) {
  return async (
    request: RulesIndexHttpRequest,
    response: RulesIndexHttpResponse,
  ): Promise<unknown> => {
    const origin = header(request, "origin");
    if (origin != null) {
      if (!originAllowed(origin, dependencies.allowedOrigins)) {
        return error(response, 403, "ORIGIN_NOT_ALLOWED");
      }
      response.set("Access-Control-Allow-Origin", origin);
      response.set("Vary", "Origin");
    }
    if (request.method === "OPTIONS") {
      response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
      response.set(
        "Access-Control-Allow-Headers",
        "Authorization, Content-Type, X-Firebase-AppCheck",
      );
      return response.status(204).send();
    }
    if (request.method !== "POST") return error(response, 405, "METHOD_NOT_ALLOWED");
    if (bodyTooLarge(request)) return error(response, 400, "BODY_TOO_LARGE");

    const appCheckToken = header(request, "x-firebase-appcheck")?.trim() ?? "";
    if (appCheckToken.length === 0) return error(response, 401, "APP_CHECK_REQUIRED");
    let validAppCheck = false;
    try {
      validAppCheck = await dependencies.verifyAppCheck(appCheckToken);
    } catch {
      validAppCheck = false;
    }
    if (!validAppCheck) return error(response, 401, "APP_CHECK_INVALID");

    const auth = header(request, "authorization");
    const token = auth?.startsWith("Bearer ") ? auth.substring(7).trim() : "";
    if (token.length === 0) return error(response, 401, "AUTH_REQUIRED");
    let uid: string | null;
    try {
      uid = await dependencies.verifyToken(token);
    } catch {
      uid = null;
    }
    if (uid == null || uid.length === 0) return error(response, 401, "AUTH_INVALID");

    const proof = readProof(request.body);
    if (proof == null) return error(response, 400, "INVALID_PAYLOAD");
    if (!proofMatches(proof, dependencies.expectedProof())) {
      await dependencies.delayAfterFailure?.();
      return error(response, 403, "PROOF_INVALID");
    }

    try {
      const release = await dependencies.latestRelease();
      if (release == null || !releaseFilePattern.test(release.file)) {
        return error(response, 404, "NO_RELEASE");
      }
      const url = await dependencies.signDownloadUrl(
        release.file,
        downloadUrlLifetimeSeconds,
      );
      return response.status(200).json({
        url,
        version: release.version,
        sha256: release.sha256,
        sizeBytes: release.sizeBytes,
        expiresInSeconds: downloadUrlLifetimeSeconds,
      });
    } catch {
      return error(response, 503, "SERVICE_UNAVAILABLE");
    }
  };
}

/** Vergleicht zwei hex-Nachweise in konstanter Zeit. */
export function proofMatches(given: string, expected: string): boolean {
  if (!proofPattern.test(expected) || !proofPattern.test(given)) return false;
  return timingSafeEqual(Buffer.from(given, "hex"), Buffer.from(expected, "hex"));
}

/** Prüft und normalisiert die Veröffentlichungsbeschreibung aus Storage. */
export function parseRelease(raw: unknown): RulesIndexRelease | null {
  if (raw == null || typeof raw !== "object") return null;
  const value = raw as Record<string, unknown>;
  const { file, sha256, sizeBytes, version } = value;
  if (typeof file !== "string" || !releaseFilePattern.test(file)) return null;
  if (typeof sha256 !== "string" || !/^[0-9a-f]{64}$/.test(sha256)) return null;
  if (typeof sizeBytes !== "number" || !Number.isFinite(sizeBytes) || sizeBytes <= 0) {
    return null;
  }
  if (typeof version !== "string" || version.length === 0) return null;
  return { file, sha256, sizeBytes, version };
}

function readProof(body: unknown): string | null {
  if (body == null || typeof body !== "object") return null;
  const proof = (body as Record<string, unknown>).proof;
  return typeof proof === "string" && proofPattern.test(proof) ? proof : null;
}

function header(request: RulesIndexHttpRequest, name: string): string | undefined {
  const raw = request.headers[name] ?? request.headers[name.toLowerCase()];
  return Array.isArray(raw) ? raw[0] : raw;
}

function bodyTooLarge(request: RulesIndexHttpRequest): boolean {
  const rawLength = header(request, "content-length");
  const declared = rawLength == null ? null : Number.parseInt(rawLength, 10);
  if (declared != null && Number.isFinite(declared) && declared > 1024) return true;
  if (request.body == null) return false;
  return Buffer.byteLength(JSON.stringify(request.body), "utf8") > 1024;
}

function originAllowed(origin: string, allowed: Array<string | RegExp>): boolean {
  return allowed.some((candidate) => candidate instanceof RegExp
    ? candidate.test(origin)
    : candidate === origin);
}

function error(response: RulesIndexHttpResponse, status: number, code: string): unknown {
  return response.status(status).json({ code });
}
