import assert from "node:assert/strict";
import test from "node:test";

import {
  FeedbackSubmissionService,
  type FeedbackIssueClient,
  type FeedbackSubmissionStore,
  type StoredSubmission,
} from "../src/feedback/submission_service.js";
import { validateSubmission } from "../src/feedback/validation.js";

const submission = validateSubmission({
  schemaVersion: 1,
  requestId: "123e4567-e89b-42d3-a456-426614174000",
  kind: "feature",
  title: "Wiederkehrende Gegner speichern",
  problem: "Wiederkehrende Gegner müssen jedes Mal neu erfasst werden.",
  desiredBehavior: "Gegner sollen als Vorlage gespeichert werden können.",
  surface: "combat",
  metadata: {
    appVersion: "1.0.1",
    buildNumber: "1",
    commit: "abcdef0",
    builtAt: "2026-10-15T19:00:00Z",
    platform: "windows",
  },
});

test("creates one issue and returns the stored result for an identical retry", async () => {
  const store = new MemoryStore();
  const github = new MemoryGithub();
  const service = new FeedbackSubmissionService(store, github, {
    testMode: false,
    now: () => new Date("2026-10-15T20:00:00Z"),
  });

  const first = await service.submit("account-a", submission);
  const second = await service.submit("account-a", submission);

  assert.deepEqual(first, {
    requestId: submission.requestId,
    status: "created",
    issueNumber: 17,
    issueUrl: "https://github.test/issues/17",
  });
  assert.deepEqual(second, first);
  assert.equal(github.created.length, 1);
});

test("rejects the same request id with changed content", async () => {
  const store = new MemoryStore();
  const service = new FeedbackSubmissionService(store, new MemoryGithub(), {
    testMode: false,
    now: () => new Date("2026-10-15T20:00:00Z"),
  });
  await service.submit("account-a", submission);

  await assert.rejects(
    () => service.submit("account-a", { ...submission, title: "Anderer Inhalt" }),
    /REQUEST_ID_CONFLICT/,
  );
});

test("marks a timeout uncertain and recovers it by correlation marker", async () => {
  const store = new MemoryStore();
  const github = new MemoryGithub();
  github.timeoutAfterCreate = true;
  const service = new FeedbackSubmissionService(store, github, {
    testMode: true,
    now: () => new Date("2026-10-15T20:00:00Z"),
  });

  const uncertain = await service.submit("account-a", submission);
  assert.equal(uncertain.status, "uncertain");
  assert.equal(github.created.length, 1);

  github.timeoutAfterCreate = false;
  const recovered = await service.getStatus("account-a", submission.requestId);
  assert.equal(recovered.status, "created");
  assert.equal(recovered.issueNumber, 17);
  assert.equal(github.created.length, 1);
});

test("does not expose a submission owned by another account", async () => {
  const store = new MemoryStore();
  const service = new FeedbackSubmissionService(store, new MemoryGithub(), {
    testMode: false,
    now: () => new Date("2026-10-15T20:00:00Z"),
  });
  await service.submit("account-a", submission);
  await assert.rejects(
    () => service.getStatus("account-b", submission.requestId),
    /NOT_FOUND/,
  );
});

class MemoryStore implements FeedbackSubmissionStore {
  private readonly entries = new Map<string, StoredSubmission>();

  async claim(
    uid: string,
    value: typeof submission,
    payloadHash: string,
    marker: string,
    now: Date,
  ) {
    const current = this.entries.get(value.requestId);
    if (current != null) {
      if (current.uid !== uid) throw new Error("NOT_FOUND");
      if (current.payloadHash !== payloadHash) throw new Error("REQUEST_ID_CONFLICT");
      return { isNew: false, submission: current };
    }
    const created: StoredSubmission = {
      uid,
      requestId: value.requestId,
      payloadHash,
      marker,
      status: "processing",
      claimedAt: now,
    };
    this.entries.set(value.requestId, created);
    return { isNew: true, submission: created };
  }

  async get(uid: string, requestId: string) {
    const value = this.entries.get(requestId);
    return value?.uid === uid ? value : null;
  }

  async markCreated(uid: string, requestId: string, issueNumber: number, issueUrl: string) {
    const value = await this.get(uid, requestId);
    if (value == null) throw new Error("NOT_FOUND");
    Object.assign(value, { status: "created", issueNumber, issueUrl });
  }

  async markUncertain(uid: string, requestId: string) {
    const value = await this.get(uid, requestId);
    if (value == null) throw new Error("NOT_FOUND");
    value.status = "uncertain";
  }

  async markFailed(uid: string, requestId: string, code: string) {
    const value = await this.get(uid, requestId);
    if (value == null) throw new Error("NOT_FOUND");
    Object.assign(value, { status: "failed", code });
  }
}

class MemoryGithub implements FeedbackIssueClient {
  readonly created: string[] = [];
  timeoutAfterCreate = false;

  async createIssue(_title: string, _body: string, _labels: string[], marker: string) {
    this.created.push(marker);
    if (this.timeoutAfterCreate) {
      throw Object.assign(new Error("timeout"), { uncertain: true });
    }
    return { number: 17, url: "https://github.test/issues/17" };
  }

  async findByMarker(marker: string) {
    return this.created.includes(marker)
      ? { number: 17, url: "https://github.test/issues/17" }
      : null;
  }
}
