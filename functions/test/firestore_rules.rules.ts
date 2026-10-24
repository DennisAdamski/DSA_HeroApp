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
    .authenticatedContext("account-a", {email_verified: true})
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
    environment!
      .authenticatedContext("account-a", {email_verified: true})
      .firestore(),
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
      joinCode: "CODE-RUNDE-A",
    });
    await setDoc(doc(admin, "groups_v2", "runde-a", "members", "owner-a"), {
      role: "owner",
    });
    await setDoc(doc(admin, "groups_v2", "runde-a", "members", "member-a"), {
      role: "member",
    });
  });

  const owner = environment!
    .authenticatedContext("owner-a", {email_verified: true})
    .firestore();
  const member = environment!
    .authenticatedContext("member-a", {email_verified: true})
    .firestore();
  const stranger = environment!
    .authenticatedContext("stranger-a", {email_verified: true})
    .firestore();

  await assertSucceeds(getDoc(doc(owner, "groups_v2", "runde-a")));
  await assertSucceeds(getDoc(doc(member, "groups_v2", "runde-a")));
  await assertFails(getDoc(doc(stranger, "groups_v2", "runde-a")));
  await assertSucceeds(
    updateDoc(doc(owner, "groups_v2", "runde-a"), { name: "Neu" }),
  );
  await assertSucceeds(
    updateDoc(doc(owner, "groups_v2", "runde-a"), { joinCode: "NEUER-CODE-1" }),
  );
  await assertFails(
    updateDoc(doc(owner, "groups_v2", "runde-a"), { joinCode: "kurz" }),
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
      joinCode: "CODE-RUNDE-B",
    });
    for (const uid of ["owner-b", "member-b"]) {
      await setDoc(doc(admin, "groups_v2", "runde-b", "members", uid), {
        role: uid === "owner-b" ? "owner" : "member",
      });
    }
  });

  const member = environment!
    .authenticatedContext("member-b", {email_verified: true})
    .firestore();
  const stranger = environment!
    .authenticatedContext("stranger-b", {email_verified: true})
    .firestore();
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

test("unbestätigte Konten können private und Gruppen-Daten nicht lesen", async () => {
  await environment!.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, "users", "account-unverified"), {version: 1});
    await setDoc(doc(admin, "groups_v2", "runde-unverified"), {
      name: "Runde",
      ownerUid: "account-unverified",
      joinCode: "CODE-UNVERIFIED",
    });
    await setDoc(
      doc(
        admin,
        "groups_v2",
        "runde-unverified",
        "members",
        "account-unverified",
      ),
      {role: "owner"},
    );
  });

  const database = environment!
    .authenticatedContext("account-unverified", {email_verified: false})
    .firestore();

  await assertFails(getDoc(doc(database, "users", "account-unverified")));
  await assertFails(getDoc(doc(database, "groups_v2", "runde-unverified")));

  const withoutClaim = environment!
    .authenticatedContext("account-unverified")
    .firestore();
  await assertFails(getDoc(doc(withoutClaim, "users", "account-unverified")));
});

const gruppe = (name: string, ownerUid: string, joinCode: string) => ({
  name,
  ownerUid,
  joinCode,
});

async function legeGruppeAn(
  groupId: string,
  ownerUid: string,
  memberUids: string[],
  joinCode = "BEITRITT-1234",
) {
  await environment!.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(
      doc(admin, "groups_v2", groupId),
      gruppe("Testrunde", ownerUid, joinCode),
    );
    await setDoc(doc(admin, "groups_v2", groupId, "members", ownerUid), {
      role: "owner",
    });
    for (const uid of memberUids) {
      await setDoc(doc(admin, "groups_v2", groupId, "members", uid), {
        role: "member",
      });
    }
  });
}

const alsNutzer = (uid: string) =>
  environment!.authenticatedContext(uid, {email_verified: true}).firestore();

test("groups_v2: Besitzer legt Gruppe und eigenen Mitgliedseintrag an", async () => {
  const owner = alsNutzer("owner-c");
  await assertSucceeds(
    setDoc(doc(owner, "groups_v2", "runde-c"), gruppe("Runde C", "owner-c", "BEITRITT-C-1")),
  );
  await assertSucceeds(
    setDoc(doc(owner, "groups_v2", "runde-c", "members", "owner-c"), {
      role: "owner",
    }),
  );
  await assertSucceeds(getDoc(doc(owner, "groups_v2", "runde-c")));
  // Fremde Besitzer-UID und fehlender Beitrittscode werden abgelehnt.
  await assertFails(
    setDoc(doc(owner, "groups_v2", "runde-c2"), gruppe("X", "jemand-anders", "BEITRITT-C-2")),
  );
  await assertFails(
    setDoc(doc(owner, "groups_v2", "runde-c3"), { name: "X", ownerUid: "owner-c" }),
  );
});

test("groups_v2: Beitritt gelingt nur mit dem richtigen Code als einfaches Mitglied", async () => {
  await legeGruppeAn("runde-d", "owner-d", []);
  const joiner = alsNutzer("joiner-d");
  const eintrag = (uid: string) =>
    doc(joiner, "groups_v2", "runde-d", "members", uid);

  await assertFails(setDoc(eintrag("joiner-d"), { role: "member", joinCode: "FALSCH-FALSCH" }));
  await assertFails(setDoc(eintrag("joiner-d"), { role: "member" }));
  await assertFails(setDoc(eintrag("joiner-d"), { role: "owner", joinCode: "BEITRITT-1234" }));
  await assertFails(setDoc(eintrag("jemand-anders"), { role: "member", joinCode: "BEITRITT-1234" }));
  await assertFails(getDoc(doc(joiner, "groups_v2", "runde-d")));

  await assertSucceeds(setDoc(eintrag("joiner-d"), { role: "member", joinCode: "BEITRITT-1234" }));
  await assertSucceeds(getDoc(doc(joiner, "groups_v2", "runde-d")));

  // Unbestätigte Konten dürfen nicht beitreten.
  const unverified = environment!
    .authenticatedContext("joiner-d2", {email_verified: false})
    .firestore();
  await assertFails(
    setDoc(doc(unverified, "groups_v2", "runde-d", "members", "joiner-d2"), {
      role: "member",
      joinCode: "BEITRITT-1234",
    }),
  );
  // Ein bestehendes Mitglied kann seinen Eintrag nicht überschreiben.
  await assertFails(setDoc(eintrag("joiner-d"), { role: "member", joinCode: "BEITRITT-1234", joinedAt: 1 }));
});

test("groups_v2: Mitglied verlässt die Gruppe, Besitzer nicht", async () => {
  await legeGruppeAn("runde-e", "owner-e", ["member-e"]);
  const member = alsNutzer("member-e");
  const owner = alsNutzer("owner-e");

  await assertFails(deleteDoc(doc(member, "groups_v2", "runde-e", "members", "owner-e")));
  await assertSucceeds(deleteDoc(doc(member, "groups_v2", "runde-e", "members", "member-e")));
  await assertFails(getDoc(doc(member, "groups_v2", "runde-e")));
  // Besitzer löscht nach dem Aufräumen die ganze Gruppe.
  await assertSucceeds(deleteDoc(doc(owner, "groups_v2", "runde-e", "members", "owner-e")));
  await assertSucceeds(deleteDoc(doc(owner, "groups_v2", "runde-e")));
});

test("groups_v2: Besitzer entfernt fremde Snapshots, Mitglieder nur den eigenen", async () => {
  await legeGruppeAn("runde-f", "owner-f", ["member-f", "member-f2"]);
  await environment!.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, "groups_v2", "runde-f", "hero_snapshots", "member-f2"), { name: "B" });
    await setDoc(doc(admin, "groups_v2", "runde-f", "hero_snapshots", "member-f"), { name: "A" });
  });
  const member = alsNutzer("member-f");
  const owner = alsNutzer("owner-f");
  await assertFails(deleteDoc(doc(member, "groups_v2", "runde-f", "hero_snapshots", "member-f2")));
  await assertSucceeds(deleteDoc(doc(member, "groups_v2", "runde-f", "hero_snapshots", "member-f")));
  await assertSucceeds(deleteDoc(doc(owner, "groups_v2", "runde-f", "hero_snapshots", "member-f2")));
});

test("groups_v2: geteilte Einträge dürfen alle Mitglieder pflegen, Fremde nicht", async () => {
  await legeGruppeAn("runde-g", "owner-g", ["member-g", "member-g2"]);
  const member = alsNutzer("member-g");
  const other = alsNutzer("member-g2");
  const owner = alsNutzer("owner-g");
  const stranger = alsNutzer("stranger-g");
  const entry = (db: ReturnType<typeof alsNutzer>) =>
    doc(db, "groups_v2", "runde-g", "shared_heroes", "npc-1");

  await assertFails(setDoc(entry(member), { name: "Fälscher", createdByUid: "owner-g" }));
  await assertFails(setDoc(entry(stranger), { name: "Fremd", createdByUid: "stranger-g" }));
  await assertSucceeds(setDoc(entry(member), { name: "Begleiter", createdByUid: "member-g" }));
  await assertSucceeds(getDoc(entry(other)));
  await assertFails(getDoc(entry(stranger)));
  // Änderungen anderer Mitglieder behalten den Ersteller.
  await assertSucceeds(updateDoc(entry(other), { name: "Begleiter II" }));
  await assertFails(updateDoc(entry(other), { createdByUid: "member-g2" }));
  await assertSucceeds(deleteDoc(entry(owner)));
  await assertFails(deleteDoc(entry(stranger)));
});

test("groups_v2: gemeinsame Notizen schreiben alle Mitglieder, aber nur als Dokument 'notizen'", async () => {
  await legeGruppeAn("runde-h", "owner-h", ["member-h"]);
  const member = alsNutzer("member-h");
  const stranger = alsNutzer("stranger-h");
  const notiz = (db: ReturnType<typeof alsNutzer>, id = "notizen") =>
    doc(db, "groups_v2", "runde-h", "shared_info", id);

  await assertSucceeds(setDoc(notiz(member), { text: "Treffpunkt: Gasthaus", updatedByUid: "member-h" }));
  await assertSucceeds(getDoc(notiz(alsNutzer("owner-h"))));
  await assertFails(setDoc(notiz(member, "anderes"), { text: "x" }));
  await assertFails(setDoc(notiz(member), { text: "x", unbekannt: 1 }));
  await assertFails(setDoc(notiz(stranger), { text: "x" }));
});

test("groups_v2: Regelprofil-Vorgabe schreibt nur der Besitzer, alle Mitglieder lesen", async () => {
  await legeGruppeAn("runde-i", "owner-i", ["member-i"]);
  const owner = alsNutzer("owner-i");
  const member = alsNutzer("member-i");
  const stranger = alsNutzer("stranger-i");
  const vorgabe = (db: ReturnType<typeof alsNutzer>) =>
    doc(db, "groups_v2", "runde-i", "shared_info", "regelprofil");
  const profil = JSON.stringify({ formatVersion: 1, catalogVersion: "house_rules_v1", pakete: [] });

  await assertFails(setDoc(vorgabe(member), { profilJson: profil }));
  await assertFails(setDoc(vorgabe(stranger), { profilJson: profil }));
  await assertSucceeds(setDoc(vorgabe(owner), { profilJson: profil, updatedByUid: "owner-i" }));
  await assertSucceeds(getDoc(vorgabe(member)));
  await assertFails(getDoc(vorgabe(stranger)));
  // Form: nur `profilJson` als nicht leerer Text, keine fremden Felder.
  await assertFails(setDoc(vorgabe(owner), { profilJson: "" }));
  await assertFails(setDoc(vorgabe(owner), { profilJson: { formatVersion: 1 } }));
  await assertFails(setDoc(vorgabe(owner), { profilJson: profil, unbekannt: 1 }));
  // Der Besitzer schreibt keine anderen Dokumente als 'notizen' und 'regelprofil'.
  await assertFails(setDoc(doc(owner, "groups_v2", "runde-i", "shared_info", "anderes"), { profilJson: profil }));
  // Notizen gehen weiterhin nur mit der Notizenform.
  await assertFails(setDoc(doc(owner, "groups_v2", "runde-i", "shared_info", "notizen"), { profilJson: profil }));
  await assertFails(deleteDoc(vorgabe(member)));
  await assertSucceeds(deleteDoc(vorgabe(owner)));
});
