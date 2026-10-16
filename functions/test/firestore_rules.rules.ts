import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test, { after, before } from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";

let environment: RulesTestEnvironment | null = null;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: "demo-feedback",
    firestore: {
      rules: readFileSync("../firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

after(async () => {
  await environment?.cleanup();
});

test("App-Nutzer können interne Feedback-Collections weder lesen noch schreiben", async () => {
  const database = environment!
    .authenticatedContext("account-a")
    .firestore();

  for (const collection of ["feedbackSubmissions", "feedbackRateLimits"]) {
    const reference = doc(database, collection, "internal-record");
    await assertFails(getDoc(reference));
    await assertFails(setDoc(reference, { status: "created" }));
  }
  assert.ok(environment != null);
});

test("Legacy-Gruppen sind anonym und angemeldet vollständig gesperrt", async () => {
  for (const database of [
    environment!.unauthenticatedContext().firestore(),
    environment!.authenticatedContext("account-a").firestore(),
  ]) {
    const group = doc(database, "gruppen", "legacy-code");
    const member = doc(group, "mitglieder", "legacy-member");
    await assertFails(getDoc(group));
    await assertFails(setDoc(group, { gruppenName: "Alt" }));
    await assertFails(getDoc(member));
    await assertFails(setDoc(member, { heroId: "hero-a", name: "Alrik" }));
    await assertFails(deleteDoc(member));
  }
});

test("groups_v2 erlaubt Lesen nur Mitgliedern und Verwaltung nur dem Besitzer", async () => {
  await environment!.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, "groups_v2", "runde-a"), {
      name: "Die Silberfüchse",
      ownerUid: "owner-a",
    });
    await setDoc(doc(admin, "groups_v2", "runde-a", "members", "owner-a"), {
      role: "owner",
    });
    await setDoc(doc(admin, "groups_v2", "runde-a", "members", "member-a"), {
      role: "member",
    });
  });

  const owner = environment!.authenticatedContext("owner-a").firestore();
  const member = environment!.authenticatedContext("member-a").firestore();
  const stranger = environment!.authenticatedContext("stranger-a").firestore();

  await assertSucceeds(getDoc(doc(owner, "groups_v2", "runde-a")));
  await assertSucceeds(getDoc(doc(member, "groups_v2", "runde-a")));
  await assertFails(getDoc(doc(stranger, "groups_v2", "runde-a")));
  await assertSucceeds(
    updateDoc(doc(owner, "groups_v2", "runde-a"), { name: "Neu" }),
  );
  await assertFails(
    updateDoc(doc(member, "groups_v2", "runde-a"), { name: "Fremd" }),
  );
  await assertFails(
    updateDoc(doc(owner, "groups_v2", "runde-a"), { ownerUid: "member-a" }),
  );

  const ownerMember = doc(owner, "groups_v2", "runde-a", "members", "member-b");
  const memberMember = doc(member, "groups_v2", "runde-a", "members", "member-b");
  await assertSucceeds(setDoc(ownerMember, { role: "member" }));
  await assertFails(setDoc(memberMember, { role: "member" }));
});

test("groups_v2 erlaubt Mitgliedern nur den eigenen Heldensnapshot", async () => {
  await environment!.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, "groups_v2", "runde-b"), {
      name: "Runde B",
      ownerUid: "owner-b",
    });
    for (const uid of ["owner-b", "member-b"]) {
      await setDoc(doc(admin, "groups_v2", "runde-b", "members", uid), {
        role: uid === "owner-b" ? "owner" : "member",
      });
    }
  });

  const member = environment!.authenticatedContext("member-b").firestore();
  const stranger = environment!.authenticatedContext("stranger-b").firestore();
  const ownSnapshot = doc(
    member,
    "groups_v2",
    "runde-b",
    "hero_snapshots",
    "member-b",
  );
  const foreignSnapshot = doc(
    member,
    "groups_v2",
    "runde-b",
    "hero_snapshots",
    "owner-b",
  );

  await assertSucceeds(setDoc(ownSnapshot, { heroId: "hero-b", name: "Rondria" }));
  await assertFails(setDoc(foreignSnapshot, { heroId: "hero-x", name: "Fremd" }));
  await assertSucceeds(getDoc(ownSnapshot));
  await assertFails(
    getDoc(doc(stranger, "groups_v2", "runde-b", "hero_snapshots", "member-b")),
  );
});
