import { createHash } from "node:crypto";

import { formatIssue } from "./issue_formatter.js";
import type {
  FeedbackResult,
  FeedbackStatus,
  FeedbackSubmission,
} from "./types.js";

export interface StoredSubmission {
  uid: string;
  requestId: string;
  payloadHash: string;
  marker: string;
  status: FeedbackStatus;
  claimedAt: Date;
  issueNumber?: number;
  issueUrl?: string;
  code?: string;
}

export interface FeedbackSubmissionStore {
  claim(
    uid: string,
    submission: FeedbackSubmission,
    payloadHash: string,
    marker: string,
    now: Date,
  ): Promise<{ isNew: boolean; submission: StoredSubmission }>;
  get(uid: string, requestId: string): Promise<StoredSubmission | null>;
  markCreated(uid: string, requestId: string, issueNumber: number, issueUrl: string): Promise<void>;
  markUncertain(uid: string, requestId: string): Promise<void>;
  markFailed(uid: string, requestId: string, code: string): Promise<void>;
}

export interface FeedbackIssueClient {
  createIssue(
    title: string,
    body: string,
    labels: string[],
    marker: string,
  ): Promise<{ number: number; url: string }>;
  findByMarker(marker: string): Promise<{ number: number; url: string } | null>;
}

/** Coordinates idempotent submission without ever blindly retrying GitHub. */
export class FeedbackSubmissionService {
  constructor(
    private readonly store: FeedbackSubmissionStore,
    private readonly github: FeedbackIssueClient,
    private readonly options: {
      testMode: boolean;
      now?: () => Date;
      processingGraceMs?: number;
    },
  ) {}

  /** Creates an issue once or returns the stored result for the same payload. */
  async submit(uid: string, submission: FeedbackSubmission): Promise<FeedbackResult> {
    const hash = payloadHash(submission);
    const marker = correlationMarker(uid, submission.requestId);
    const now = this.options.now?.() ?? new Date();
    const claim = await this.store.claim(uid, submission, hash, marker, now);
    if (!claim.isNew) {
      return this.resolveStored(claim.submission, now);
    }

    const issue = formatIssue(submission, {
      marker,
      testMode: this.options.testMode,
    });
    try {
      const created = await this.github.createIssue(
        issue.title,
        issue.body,
        issue.labels,
        marker,
      );
      await this.store.markCreated(uid, submission.requestId, created.number, created.url);
      return result(submission.requestId, "created", created);
    } catch (error) {
      if (isUncertain(error)) {
        await this.store.markUncertain(uid, submission.requestId);
        return result(submission.requestId, "uncertain");
      }
      await this.store.markFailed(uid, submission.requestId, "GITHUB_REJECTED");
      throw new FeedbackServiceError("GITHUB_REJECTED");
    }
  }

  /** Returns an owned status and reconciles ambiguous GitHub outcomes by marker. */
  async getStatus(uid: string, requestId: string): Promise<FeedbackResult> {
    const stored = await this.store.get(uid, requestId);
    if (stored == null) throw new FeedbackServiceError("NOT_FOUND");
    const now = this.options.now?.() ?? new Date();
    return this.resolveStored(stored, now);
  }

  private async resolveStored(stored: StoredSubmission, now: Date): Promise<FeedbackResult> {
    if (stored.status === "created") return storedResult(stored);
    if (stored.status === "failed") return storedResult(stored);

    const grace = this.options.processingGraceMs ?? 30_000;
    const isFresh = now.getTime() - stored.claimedAt.getTime() < grace;
    if (stored.status === "processing" && isFresh) {
      return result(stored.requestId, "processing");
    }
    const found = await this.github.findByMarker(stored.marker);
    if (found != null) {
      await this.store.markCreated(stored.uid, stored.requestId, found.number, found.url);
      return result(stored.requestId, "created", found);
    }
    if (stored.status !== "uncertain") {
      await this.store.markUncertain(stored.uid, stored.requestId);
    }
    return result(stored.requestId, "uncertain");
  }
}

/** Error with a stable API code and no upstream response details. */
export class FeedbackServiceError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

function result(
  requestId: string,
  status: FeedbackStatus,
  issue?: { number: number; url: string },
): FeedbackResult {
  return {
    requestId,
    status,
    ...(issue == null ? {} : { issueNumber: issue.number, issueUrl: issue.url }),
  };
}

function storedResult(stored: StoredSubmission): FeedbackResult {
  return {
    requestId: stored.requestId,
    status: stored.status,
    ...(stored.issueNumber == null ? {} : { issueNumber: stored.issueNumber }),
    ...(stored.issueUrl == null ? {} : { issueUrl: stored.issueUrl }),
    ...(stored.code == null ? {} : { code: stored.code }),
  };
}

function payloadHash(submission: FeedbackSubmission): string {
  return createHash("sha256").update(canonicalJson(submission)).digest("hex");
}

function correlationMarker(uid: string, requestId: string): string {
  const value = createHash("sha256").update(`${uid}:${requestId}`).digest("hex");
  return `feedback:${value}`;
}

function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (value != null && typeof value === "object") {
    const record = value as Record<string, unknown>;
    const entries = Object.keys(record)
      .filter((key) => record[key] !== undefined)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonicalJson(record[key])}`);
    return `{${entries.join(",")}}`;
  }
  return JSON.stringify(value);
}

function isUncertain(error: unknown): boolean {
  return error != null
    && typeof error === "object"
    && "uncertain" in error
    && (error as { uncertain: unknown }).uncertain === true;
}
