import { createHash } from "node:crypto";

import {
  FieldValue,
  Timestamp,
  type Firestore,
} from "firebase-admin/firestore";

import type { RegistrationTicketStore } from "./registration_service.js";

/** Firestore persistence for private invite tickets and rate-limit counters. */
export class FirestoreRegistrationTicketStore implements RegistrationTicketStore {
  constructor(private readonly firestore: Firestore) {}

  async allowAttempt(
    key: string,
    maxAttempts: number,
    now: Date,
    windowMs: number,
  ): Promise<boolean> {
    const reference = this.firestore
      .collection("registration_invite_limits")
      .doc(hashKey(key));
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      const data = snapshot.data();
      const windowStart = data?.windowStart instanceof Timestamp
        ? data.windowStart.toDate()
        : null;
      const currentWindow = windowStart != null
        && now.getTime() - windowStart.getTime() < windowMs;
      const count = currentWindow && typeof data?.count === "number"
        ? data.count
        : 0;
      if (count >= maxAttempts) {
        return false;
      }
      const effectiveStart = currentWindow ? windowStart : now;
      transaction.set(reference, {
        count: count + 1,
        windowStart: Timestamp.fromDate(effectiveStart),
        expiresAt: Timestamp.fromMillis(effectiveStart.getTime() + windowMs * 2),
      });
      return true;
    });
  }

  async issueTicket(email: string, expiresAt: Date): Promise<void> {
    const reference = this.firestore
      .collection("registration_invites")
      .doc(hashKey(email));
    await reference.set({
      normalizedEmail: email,
      keywordVersion: "active",
      expiresAt: Timestamp.fromDate(expiresAt),
      usedAt: null,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  async consumeTicket(email: string, now: Date): Promise<boolean> {
    const reference = this.firestore
      .collection("registration_invites")
      .doc(hashKey(email));
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      const data = snapshot.data();
      const expiresAt = data?.expiresAt instanceof Timestamp
        ? data.expiresAt.toDate()
        : null;
      const valid = data?.normalizedEmail === email
        && data?.usedAt == null
        && expiresAt != null
        && expiresAt > now;
      if (!valid) {
        return false;
      }
      transaction.update(reference, { usedAt: Timestamp.fromDate(now) });
      return true;
    });
  }
}

function hashKey(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}
