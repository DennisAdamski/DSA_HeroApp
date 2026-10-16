import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test, { after } from "node:test";

import {
  assertFails,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";

let environment: RulesTestEnvironment | null = null;

after(async () => {
  await environment?.cleanup();
});

test("App-Nutzer können interne Feedback-Collections weder lesen noch schreiben", async () => {
  environment = await initializeTestEnvironment({
    projectId: "demo-feedback",
    firestore: {
      rules: readFileSync("../firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
  const database = environment
    .authenticatedContext("account-a")
    .firestore();

  for (const collection of ["feedbackSubmissions", "feedbackRateLimits"]) {
    const reference = doc(database, collection, "internal-record");
    await assertFails(getDoc(reference));
    await assertFails(setDoc(reference, { status: "created" }));
  }
  assert.ok(environment != null);
});
