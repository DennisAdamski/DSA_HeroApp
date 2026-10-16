import type { FeedbackResult } from "./types.js";
import { FeedbackServiceError } from "./submission_service.js";
import { FeedbackValidationError } from "./validation.js";

export interface FeedbackHttpRequest {
  method: string;
  path: string;
  headers: Record<string, string | string[] | undefined>;
  body?: unknown;
}

export interface FeedbackHttpResponse {
  status(code: number): FeedbackHttpResponse;
  set(name: string, value: string): FeedbackHttpResponse;
  json(value: unknown): unknown;
  send(value?: unknown): unknown;
}

export interface FeedbackApiDependencies {
  allowedOrigins: Array<string | RegExp>;
  verifyToken(token: string): Promise<string | null>;
  submit(uid: string, body: unknown): Promise<FeedbackResult>;
  status(uid: string, requestId: string): Promise<FeedbackResult>;
}

/** Builds the HTTP boundary around injectable authentication and service logic. */
export function createFeedbackApi(dependencies: FeedbackApiDependencies) {
  return async (
    request: FeedbackHttpRequest,
    response: FeedbackHttpResponse,
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
      response.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
      response.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
      return response.status(204).send();
    }
    if (bodyTooLarge(request)) return error(response, 400, "BODY_TOO_LARGE");

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

    try {
      if (request.method === "POST" && request.path === "/submissions") {
        const result = await dependencies.submit(uid, request.body);
        return response.status(statusFor(result, true)).json(result);
      }
      const match = request.method === "GET"
        ? /^\/submissions\/([^/]+)$/.exec(request.path)
        : null;
      if (match != null) {
        const result = await dependencies.status(uid, decodeURIComponent(match[1]));
        return response.status(statusFor(result, false)).json(result);
      }
      return error(response, 404, "NOT_FOUND");
    } catch (caught) {
      if (caught instanceof FeedbackValidationError) {
        return error(response, 400, "INVALID_PAYLOAD", caught.message);
      }
      if (caught instanceof FeedbackServiceError || caught instanceof Error) {
        const code = caught instanceof FeedbackServiceError ? caught.code : caught.message;
        return mapServiceError(response, code);
      }
      return error(response, 503, "SERVICE_UNAVAILABLE");
    }
  };
}

function header(request: FeedbackHttpRequest, name: string): string | undefined {
  const raw = request.headers[name] ?? request.headers[name.toLowerCase()];
  return Array.isArray(raw) ? raw[0] : raw;
}

function bodyTooLarge(request: FeedbackHttpRequest): boolean {
  const rawLength = header(request, "content-length");
  const declared = rawLength == null ? null : Number.parseInt(rawLength, 10);
  if (declared != null && Number.isFinite(declared) && declared > 32 * 1024) return true;
  if (request.body == null) return false;
  return Buffer.byteLength(JSON.stringify(request.body), "utf8") > 32 * 1024;
}

function originAllowed(origin: string, allowed: Array<string | RegExp>): boolean {
  return allowed.some((candidate) => candidate instanceof RegExp
    ? candidate.test(origin)
    : candidate === origin);
}

function statusFor(result: FeedbackResult, createdRoute: boolean): number {
  if (result.status === "created") return createdRoute ? 201 : 200;
  if (result.status === "processing" || result.status === "uncertain") return 202;
  return 503;
}

function mapServiceError(response: FeedbackHttpResponse, code: string): unknown {
  if (code === "NOT_FOUND") return error(response, 404, code);
  if (code === "REQUEST_ID_CONFLICT") return error(response, 409, code);
  if (code === "RATE_LIMITED") return error(response, 429, code);
  if (code === "SERVICE_DISABLED") return error(response, 503, code);
  return error(response, 503, "SERVICE_UNAVAILABLE");
}

function error(
  response: FeedbackHttpResponse,
  status: number,
  code: string,
  message?: string,
): unknown {
  return response.status(status).json({ code, ...(message == null ? {} : { message }) });
}
