import {
  RegistrationServiceError,
  type RegistrationInviteRequest,
} from "./registration_service.js";

export interface RegistrationHttpRequest {
  method: string;
  path: string;
  headers: Record<string, string | string[] | undefined>;
  body?: unknown;
  ip?: string;
}

export interface RegistrationHttpResponse {
  status(code: number): RegistrationHttpResponse;
  set(name: string, value: string): RegistrationHttpResponse;
  json(value: unknown): unknown;
  send(value?: unknown): unknown;
}

export interface RegistrationApiDependencies {
  allowedOrigins: Array<string | RegExp>;
  verifyAppCheck(token: string): Promise<boolean>;
  issue(request: Omit<RegistrationInviteRequest, "now">): Promise<void>;
}

/** Creates the unauthenticated but App-Check-protected invite endpoint. */
export function createRegistrationInviteApi(
  dependencies: RegistrationApiDependencies,
) {
  return async (
    request: RegistrationHttpRequest,
    response: RegistrationHttpResponse,
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
        "Content-Type, X-Firebase-AppCheck",
      );
      return response.status(204).send();
    }
    if (request.method !== "POST" || request.path !== "/tickets") {
      return error(response, 404, "NOT_FOUND");
    }
    if (bodyTooLarge(request)) {
      return error(response, 400, "BODY_TOO_LARGE");
    }

    const token = header(request, "x-firebase-appcheck")?.trim() ?? "";
    if (token.length === 0) {
      return error(response, 401, "APP_CHECK_REQUIRED");
    }
    try {
      if (!await dependencies.verifyAppCheck(token)) {
        return error(response, 401, "APP_CHECK_INVALID");
      }
    } catch {
      return error(response, 401, "APP_CHECK_INVALID");
    }

    const body = request.body as Record<string, unknown> | null;
    const email = typeof body?.email === "string" ? body.email : "";
    const keyword = typeof body?.keyword === "string" ? body.keyword : "";
    const callerKey = request.ip?.trim() ?? "";
    try {
      await dependencies.issue({ email, keyword, callerKey });
      return response.status(204).send();
    } catch (caught) {
      if (!(caught instanceof RegistrationServiceError)) {
        return error(response, 503, "SERVICE_UNAVAILABLE");
      }
      if (caught.code === "RATE_LIMITED") {
        return error(response, 429, caught.code);
      }
      if (caught.code === "INVITE_INVALID") {
        return error(response, 403, caught.code);
      }
      return error(response, 400, caught.code);
    }
  };
}

function header(
  request: RegistrationHttpRequest,
  name: string,
): string | undefined {
  const raw = request.headers[name] ?? request.headers[name.toLowerCase()];
  return Array.isArray(raw) ? raw[0] : raw;
}

function bodyTooLarge(request: RegistrationHttpRequest): boolean {
  const rawLength = header(request, "content-length");
  const declared = rawLength == null ? 0 : Number.parseInt(rawLength, 10);
  if (Number.isFinite(declared) && declared > 4096) return true;
  if (request.body == null) return false;
  return Buffer.byteLength(JSON.stringify(request.body), "utf8") > 4096;
}

function originAllowed(origin: string, allowed: Array<string | RegExp>): boolean {
  return allowed.some((candidate) => candidate instanceof RegExp
    ? candidate.test(origin)
    : candidate === origin);
}

function error(
  response: RegistrationHttpResponse,
  status: number,
  code: string,
): unknown {
  return response.status(status).json({ code });
}
