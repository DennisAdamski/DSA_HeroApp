import assert from "node:assert/strict";
import test from "node:test";

import {
  verifyExistingAccounts,
  type ExistingAccountAdmin,
} from "../scripts/verify_existing_accounts.js";

test("Trockenlauf zählt unbestätigte E-Mail-Konten ohne Änderungen", async () => {
  const updated: string[] = [];
  const admin = fakeAdmin(updated);

  const report = await verifyExistingAccounts(admin, {apply: false});

  assert.deepEqual(report, {
    scanned: 3,
    alreadyVerified: 1,
    withoutEmail: 1,
    changed: 0,
    pending: 1,
  });
  assert.deepEqual(updated, []);
});

test("Anwendung bestätigt bestehende E-Mail-Konten über alle Seiten", async () => {
  const updated: string[] = [];
  const admin = fakeAdmin(updated);

  const report = await verifyExistingAccounts(admin, {apply: true});

  assert.equal(report.changed, 1);
  assert.equal(report.pending, 0);
  assert.deepEqual(updated, ["unverified"]);
});

// Bildet zwei Seiten ab, damit Trockenlauf und Pagination gemeinsam geprüft sind.
function fakeAdmin(updated: string[]): ExistingAccountAdmin {
  return {
    async listUsers(_maxResults, pageToken) {
      if (pageToken == null) {
        return {
          users: [
            {uid: "verified", email: "verified@example.de", emailVerified: true},
            {
              uid: "unverified",
              email: "unverified@example.de",
              emailVerified: false,
            },
          ],
          pageToken: "page-2",
        };
      }
      return {
        users: [{uid: "anonymous", emailVerified: false}],
      };
    },
    async markEmailVerified(uid) {
      updated.push(uid);
    },
  };
}
