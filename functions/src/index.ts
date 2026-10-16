import { createHash, timingSafeEqual } from "node:crypto";

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getAppCheck } from "firebase-admin/app-check";
import { getFirestore } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";
import type { HttpsOptions } from "firebase-functions/v2/https";
import { beforeUserCreated, HttpsError } from "firebase-functions/v2/identity";
import { defineBoolean, defineSecret } from "firebase-functions/params";

import { createFeedbackApi } from "./feedback/api.js";
import { GitHubIssueClient } from "./feedback/github_issue_client.js";
import { FeedbackSubmissionService } from "./feedback/submission_service.js";
import { FirestoreFeedbackSubmissionStore } from "./feedback/submission_store.js";
import { validateSubmission } from "./feedback/validation.js";
import { createRegistrationInviteApi } from "./auth/registration_api.js";
import { RegistrationInviteService } from "./auth/registration_service.js";
import { FirestoreRegistrationTicketStore } from "./auth/registration_store.js";

initializeApp();

const githubToken = defineSecret("GITHUB_FEEDBACK_TOKEN");
const registrationKeyword = defineSecret("REGISTRATION_KEYWORD");
const testEnabled = defineBoolean("FEEDBACK_TEST_ENABLED", { default: false });
const productionEnabled = defineBoolean("FEEDBACK_PRODUCTION_ENABLED", { default: false });

const commonOptions: HttpsOptions = {
  region: "europe-west10",
  secrets: [githubToken],
  timeoutSeconds: 15,
  maxInstances: 5,
  cors: false,
};

export const feedbackApiTest = onRequest(commonOptions, async (request, response) => {
  if (!testEnabled.value()) {
    response.status(503).json({ code: "SERVICE_DISABLED" });
    return;
  }
  const api = buildApi({
    testMode: true,
    allowedOrigins: [
      "https://heldensync-test.web.app",
      "https://heldensync-test.firebaseapp.com",
      /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/,
    ],
  });
  await api(request, response);
});

export const feedbackApi = onRequest(commonOptions, async (request, response) => {
  if (!productionEnabled.value()) {
    response.status(503).json({ code: "SERVICE_DISABLED" });
    return;
  }
  const api = buildApi({
    testMode: false,
    allowedOrigins: [
      "https://heldensync-ccf0b.web.app",
      "https://heldensync-ccf0b.firebaseapp.com",
    ],
  });
  await api(request, response);
});

export const registrationInviteApi = onRequest({
  region: "europe-west10",
  secrets: [registrationKeyword],
  timeoutSeconds: 10,
  maxInstances: 5,
  cors: false,
}, async (request, response) => {
  const store = new FirestoreRegistrationTicketStore(getFirestore());
  const service = new RegistrationInviteService(store, {
    verifyKeyword: async (candidate) => secureKeywordMatches(
      candidate,
      registrationKeyword.value(),
    ),
  });
  const api = createRegistrationInviteApi({
    allowedOrigins: [
      "https://heldensync-test.web.app",
      "https://heldensync-test.firebaseapp.com",
      "https://heldensync-ccf0b.web.app",
      "https://heldensync-ccf0b.firebaseapp.com",
      /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/,
    ],
    verifyAppCheck: async (token) => {
      await getAppCheck().verifyToken(token);
      return true;
    },
    issue: (invite) => service.issue(invite),
  });
  await api(request, response);
});

export const registrationGate = beforeUserCreated({
  region: "europe-west10",
  timeoutSeconds: 10,
}, async (event) => {
  const email = event.data?.email;
  if (email == null) {
    throw new HttpsError("permission-denied", "Registrierung nicht freigegeben.");
  }
  const store = new FirestoreRegistrationTicketStore(getFirestore());
  const service = new RegistrationInviteService(store, {
    verifyKeyword: async () => false,
  });
  if (!await service.consume(email)) {
    throw new HttpsError("permission-denied", "Registrierung nicht freigegeben.");
  }
});

function buildApi(options: {
  testMode: boolean;
  allowedOrigins: Array<string | RegExp>;
}) {
  const store = new FirestoreFeedbackSubmissionStore(getFirestore());
  const github = new GitHubIssueClient({
    owner: "DennisAdamski",
    repository: "DSA_HeroApp",
    token: githubToken.value(),
  });
  const service = new FeedbackSubmissionService(store, github, {
    testMode: options.testMode,
  });
  return createFeedbackApi({
    allowedOrigins: options.allowedOrigins,
    verifyToken: async (token) => {
      const decoded = await getAuth().verifyIdToken(token, true);
      return decoded.email_verified === true ? decoded.uid : null;
    },
    verifyAppCheck: async (token) => {
      await getAppCheck().verifyToken(token);
      return true;
    },
    submit: (uid, body) => service.submit(uid, validateSubmission(body)),
    status: (uid, requestId) => service.getStatus(uid, requestId),
  });
}

function secureKeywordMatches(candidate: string, expected: string): boolean {
  const candidateDigest = createHash("sha256").update(candidate.trim()).digest();
  const expectedDigest = createHash("sha256").update(expected.trim()).digest();
  return timingSafeEqual(candidateDigest, expectedDigest);
}
