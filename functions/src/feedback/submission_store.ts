import { createHash } from "node:crypto";

import {
  FieldValue,
  Timestamp,
  type DocumentData,
  type Firestore,
} from "firebase-admin/firestore";

import {
  FeedbackServiceError,
  type FeedbackSubmissionStore,
  type StoredSubmission,
} from "./submission_service.js";
import type { FeedbackStatus, FeedbackSubmission } from "./types.js";

const hourMs = 60 * 60 * 1000;
const dayMs = 24 * hourMs;
const metadataRetentionMs = 7 * dayMs;

/** Firestore-backed atomic claims and per-account rolling quotas. */
export class FirestoreFeedbackSubmissionStore implements FeedbackSubmissionStore {
  constructor(private readonly firestore: Firestore) {}

  /** Reserves a request once and charges quota only for a genuinely new claim. */
  async claim(
    uid: string,
    submission: FeedbackSubmission,
    payloadHash: string,
    marker: string,
    now: Date,
  ): Promise<{ isNew: boolean; submission: StoredSubmission }> {
    const requestRef = this.firestore
      .collection("feedbackSubmissions")
      .doc(documentKey(uid, submission.requestId));
    const rateRef = this.firestore
      .collection("feedbackRateLimits")
      .doc(documentKey(uid, "rate"));
    return this.firestore.runTransaction(async (transaction) => {
      const current = await transaction.get(requestRef);
      if (current.exists) {
        const stored = decodeStored(current.data() ?? {});
        if (stored.payloadHash !== payloadHash) {
          throw new FeedbackServiceError("REQUEST_ID_CONFLICT");
        }
        return { isNew: false, submission: stored };
      }
      const rate = await transaction.get(rateRef);
      const timestamps = decodeDates(rate.data()?.timestamps);
      const next = nextRateLimit(timestamps, now);
      const expiresAt = new Date(now.getTime() + metadataRetentionMs);
      const stored: StoredSubmission = {
        uid,
        requestId: submission.requestId,
        payloadHash,
        marker,
        status: "processing",
        claimedAt: now,
      };
      transaction.set(rateRef, {
        uid,
        timestamps: next,
        expiresAt,
      });
      transaction.create(requestRef, {
        ...stored,
        expiresAt,
      });
      return { isNew: true, submission: stored };
    });
  }

  /** Loads only the document whose key is derived from the authenticated account. */
  async get(uid: string, requestId: string): Promise<StoredSubmission | null> {
    const snapshot = await this.firestore
      .collection("feedbackSubmissions")
      .doc(documentKey(uid, requestId))
      .get();
    return snapshot.exists ? decodeStored(snapshot.data() ?? {}) : null;
  }

  /** Stores the public reference and removes any obsolete error marker. */
  async markCreated(
    uid: string,
    requestId: string,
    issueNumber: number,
    issueUrl: string,
  ): Promise<void> {
    await this.update(uid, requestId, {
      status: "created",
      issueNumber,
      issueUrl,
      code: FieldValue.delete(),
    });
  }

  /** Records that a POST may have succeeded and must not be repeated. */
  async markUncertain(uid: string, requestId: string): Promise<void> {
    await this.update(uid, requestId, { status: "uncertain" });
  }

  /** Stores a stable failure code without upstream response or user text. */
  async markFailed(uid: string, requestId: string, code: string): Promise<void> {
    await this.update(uid, requestId, { status: "failed", code });
  }

  private async update(uid: string, requestId: string, data: DocumentData): Promise<void> {
    const reference = this.firestore
      .collection("feedbackSubmissions")
      .doc(documentKey(uid, requestId));
    await reference.update(data);
  }
}

/** Applies the 3/hour and 10/day rolling limits to a new submission. */
export function nextRateLimit(timestamps: Date[], now: Date): Date[] {
  const daily = timestamps.filter((value) => now.getTime() - value.getTime() < dayMs);
  const hourly = daily.filter((value) => now.getTime() - value.getTime() < hourMs);
  if (hourly.length >= 3 || daily.length >= 10) {
    throw new FeedbackServiceError("RATE_LIMITED");
  }
  return [...daily, now];
}

function documentKey(uid: string, value: string): string {
  return createHash("sha256").update(`${uid}:${value}`).digest("hex");
}

function decodeStored(data: DocumentData): StoredSubmission {
  return {
    uid: String(data.uid ?? ""),
    requestId: String(data.requestId ?? ""),
    payloadHash: String(data.payloadHash ?? ""),
    marker: String(data.marker ?? ""),
    status: String(data.status ?? "failed") as FeedbackStatus,
    claimedAt: decodeDate(data.claimedAt) ?? new Date(0),
    ...(typeof data.issueNumber === "number" ? { issueNumber: data.issueNumber } : {}),
    ...(typeof data.issueUrl === "string" ? { issueUrl: data.issueUrl } : {}),
    ...(typeof data.code === "string" ? { code: data.code } : {}),
  };
}

function decodeDates(input: unknown): Date[] {
  return Array.isArray(input)
    ? input.map(decodeDate).filter((value): value is Date => value != null)
    : [];
}

function decodeDate(input: unknown): Date | null {
  if (input instanceof Date) return input;
  if (input instanceof Timestamp) return input.toDate();
  return null;
}
