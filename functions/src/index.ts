import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getAppCheck } from "firebase-admin/app-check";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onRequest } from "firebase-functions/v2/https";
import type { HttpsOptions } from "firebase-functions/v2/https";
import { defineBoolean, defineSecret } from "firebase-functions/params";

import { createFeedbackApi } from "./feedback/api.js";
import { GitHubIssueClient } from "./feedback/github_issue_client.js";
import { FeedbackSubmissionService } from "./feedback/submission_service.js";
import { FirestoreFeedbackSubmissionStore } from "./feedback/submission_store.js";
import { validateSubmission } from "./feedback/validation.js";
import { createRulesIndexApi, parseRelease } from "./rules_index/api.js";

initializeApp();

const githubToken = defineSecret("GITHUB_FEEDBACK_TOKEN");
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

// Zugang zur Regel-Wissensbasis (SPIEL-04): kurzlebige Download-URL für
// bestätigte Konten mit gültigem Passwortnachweis. Die Datei liegt unter
// `rules/` in Storage und ist für Clients nicht lesbar (storage.rules).
const rulesIndexProof = defineSecret("RULES_INDEX_PROOF");
const rulesIndexTestEnabled = defineBoolean("RULES_INDEX_TEST_ENABLED", { default: false });
const rulesIndexProductionEnabled = defineBoolean("RULES_INDEX_PRODUCTION_ENABLED", { default: false });

const rulesIndexOptions: HttpsOptions = {
  region: "europe-west10",
  secrets: [rulesIndexProof],
  timeoutSeconds: 30,
  maxInstances: 3,
  cors: false,
};

export const rulesIndexApiTest = onRequest(rulesIndexOptions, async (request, response) => {
  if (!rulesIndexTestEnabled.value()) {
    response.status(503).json({ code: "SERVICE_DISABLED" });
    return;
  }
  await buildRulesIndexApi([
    "https://heldensync-test.web.app",
    "https://heldensync-test.firebaseapp.com",
    /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/,
  ])(request, response);
});

export const rulesIndexApi = onRequest(rulesIndexOptions, async (request, response) => {
  if (!rulesIndexProductionEnabled.value()) {
    response.status(503).json({ code: "SERVICE_DISABLED" });
    return;
  }
  await buildRulesIndexApi([
    "https://heldensync-ccf0b.web.app",
    "https://heldensync-ccf0b.firebaseapp.com",
  ])(request, response);
});

function buildRulesIndexApi(allowedOrigins: Array<string | RegExp>) {
  const bucket = getStorage().bucket();
  return createRulesIndexApi({
    allowedOrigins,
    verifyToken: async (token) => {
      const decoded = await getAuth().verifyIdToken(token, true);
      return decoded.email_verified === true ? decoded.uid : null;
    },
    verifyAppCheck: async (token) => {
      await getAppCheck().verifyToken(token);
      return true;
    },
    expectedProof: () => rulesIndexProof.value().trim(),
    latestRelease: async () => {
      const [contents] = await bucket.file("rules/latest.json").download();
      return parseRelease(JSON.parse(contents.toString("utf8")));
    },
    signDownloadUrl: async (file, seconds) => {
      const [url] = await bucket.file(`rules/${file}`).getSignedUrl({
        version: "v4",
        action: "read",
        expires: Date.now() + seconds * 1000,
      });
      return url;
    },
    delayAfterFailure: () => new Promise((resolve) => setTimeout(resolve, 1000)),
  });
}