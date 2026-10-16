import {
  feedbackSurfaces,
  type BugDiagnostics,
  type FeedbackBaseMetadata,
  type FeedbackSubmission,
} from "./types.js";

const uuidV4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const baseKeys = ["schemaVersion", "requestId", "kind", "title", "surface", "metadata"];
const metadataKeys = ["appVersion", "buildNumber", "commit", "builtAt", "platform"];
const diagnosticKeys = [
  "operatingSystem",
  "operatingSystemVersion",
  "locale",
  "viewportWidth",
  "viewportHeight",
  "devicePixelRatio",
  "layoutClass",
  "interfaceVariant",
  "brightness",
  "tableMode",
  "firebaseAvailable",
  "authenticated",
];
const graphemeSegmenter = new Intl.Segmenter("de", { granularity: "grapheme" });

/** Validates and normalizes the complete public feedback payload. */
export function validateSubmission(input: unknown): FeedbackSubmission {
  const value = record(input, "payload");
  const kind = text(value.kind, "kind", 3, 20);
  const kindKeys = kind === "bug"
    ? ["actualBehavior", "expectedBehavior", "reproductionSteps", "diagnostics"]
    : kind === "feature"
      ? ["problem", "desiredBehavior"]
      : kind === "rules"
        ? ["question", "source", "interpretation"]
        : fail("kind ist ungültig.");
  rejectUnknown(value, [...baseKeys, ...kindKeys]);

  if (value.schemaVersion !== 1) fail("schemaVersion muss 1 sein.");
  const requestId = text(value.requestId, "requestId", 36, 36);
  if (!uuidV4.test(requestId)) fail("requestId muss eine UUID v4 sein.");
  const title = text(value.title, "title", 5, 120);
  const surface = text(value.surface, "surface", 2, 40);
  if (!feedbackSurfaces.includes(surface as never)) fail("surface ist ungültig.");
  const metadata = validateMetadata(value.metadata);
  const common = {
    schemaVersion: 1 as const,
    requestId,
    title,
    surface: surface as FeedbackSubmission["surface"],
    metadata,
  };

  if (kind === "bug") {
    return {
      ...common,
      kind,
      actualBehavior: text(value.actualBehavior, "actualBehavior", 20, 8000),
      expectedBehavior: text(value.expectedBehavior, "expectedBehavior", 20, 8000),
      reproductionSteps: optionalText(value.reproductionSteps, "reproductionSteps", 8000),
      diagnostics: value.diagnostics == null ? undefined : validateDiagnostics(value.diagnostics),
    };
  }
  if (kind === "feature") {
    return {
      ...common,
      kind,
      problem: text(value.problem, "problem", 20, 8000),
      desiredBehavior: text(value.desiredBehavior, "desiredBehavior", 20, 8000),
    };
  }
  return {
    ...common,
    kind: "rules",
    question: text(value.question, "question", 20, 8000),
    source: optionalText(value.source, "source", 300),
    interpretation: optionalText(value.interpretation, "interpretation", 8000),
  };
}

function validateMetadata(input: unknown): FeedbackBaseMetadata {
  const value = record(input, "metadata");
  rejectUnknown(value, metadataKeys);
  return {
    appVersion: text(value.appVersion, "metadata.appVersion", 1, 40),
    buildNumber: text(value.buildNumber, "metadata.buildNumber", 1, 40),
    commit: text(value.commit, "metadata.commit", 0, 80),
    builtAt: text(value.builtAt, "metadata.builtAt", 0, 80),
    platform: text(value.platform, "metadata.platform", 1, 40),
  };
}

function validateDiagnostics(input: unknown): BugDiagnostics {
  const value = record(input, "diagnostics");
  rejectUnknown(value, diagnosticKeys);
  return {
    operatingSystem: text(value.operatingSystem, "diagnostics.operatingSystem", 1, 80),
    operatingSystemVersion: text(value.operatingSystemVersion, "diagnostics.operatingSystemVersion", 0, 200),
    locale: text(value.locale, "diagnostics.locale", 1, 40),
    viewportWidth: finiteNumber(value.viewportWidth, "diagnostics.viewportWidth", 1, 20000),
    viewportHeight: finiteNumber(value.viewportHeight, "diagnostics.viewportHeight", 1, 20000),
    devicePixelRatio: finiteNumber(value.devicePixelRatio, "diagnostics.devicePixelRatio", 0.1, 10),
    layoutClass: oneOf(value.layoutClass, "diagnostics.layoutClass", ["compact", "tabletPortrait", "tabletLandscape", "desktopWide"]),
    interfaceVariant: oneOf(value.interfaceVariant, "diagnostics.interfaceVariant", ["codex", "kartograph"]),
    brightness: oneOf(value.brightness, "diagnostics.brightness", ["light", "dark"]),
    tableMode: oneOf(value.tableMode, "diagnostics.tableMode", ["automatic", "table", "cards"]),
    firebaseAvailable: boolean(value.firebaseAvailable, "diagnostics.firebaseAvailable"),
    authenticated: boolean(value.authenticated, "diagnostics.authenticated"),
  };
}

function record(input: unknown, field: string): Record<string, unknown> {
  if (input == null || typeof input !== "object" || Array.isArray(input)) {
    return fail(`${field} muss ein Objekt sein.`);
  }
  return input as Record<string, unknown>;
}

function rejectUnknown(value: Record<string, unknown>, allowed: readonly string[]): void {
  const unknown = Object.keys(value).find((key) => !allowed.includes(key));
  if (unknown != null) fail(`Unbekanntes Feld: ${unknown}`);
}

function text(input: unknown, field: string, min: number, max: number): string {
  if (typeof input !== "string") return fail(`${field} muss Text sein.`);
  const value = input.trim();
  const length = [...graphemeSegmenter.segment(value)].length;
  if (length < min || length > max) {
    return fail(`${field} muss zwischen ${min} und ${max} Zeichen lang sein.`);
  }
  return value;
}

function optionalText(input: unknown, field: string, max: number): string | undefined {
  if (input == null || input === "") return undefined;
  return text(input, field, 1, max);
}

function finiteNumber(input: unknown, field: string, min: number, max: number): number {
  if (typeof input !== "number" || !Number.isFinite(input) || input < min || input > max) {
    return fail(`${field} ist ungültig.`);
  }
  return input;
}

function boolean(input: unknown, field: string): boolean {
  if (typeof input !== "boolean") return fail(`${field} muss boolesch sein.`);
  return input;
}

function oneOf<T extends string>(input: unknown, field: string, values: readonly T[]): T {
  if (typeof input !== "string" || !values.includes(input as T)) {
    return fail(`${field} ist ungültig.`);
  }
  return input as T;
}

function fail(message: string): never {
  throw new FeedbackValidationError(message);
}

/** A safe validation error whose message may be returned to the app. */
export class FeedbackValidationError extends Error {}
