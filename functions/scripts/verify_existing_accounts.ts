import {resolve} from "node:path";
import {pathToFileURL} from "node:url";

import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";

const projectId = "heldensync-ccf0b";

/** Minimale Admin-Schnittstelle für die einmalige Bestandsmigration. */
export interface ExistingAccountAdmin {
  listUsers(
    maxResults: number,
    pageToken?: string,
  ): Promise<ExistingAccountPage>;
  markEmailVerified(uid: string): Promise<void>;
}

/** Für die Migration benötigte Teilmenge eines Firebase-Benutzers. */
export interface ExistingAccount {
  uid: string;
  email?: string;
  emailVerified: boolean;
}

/** Seite der paginierten Firebase-Auth-Benutzerliste. */
export interface ExistingAccountPage {
  users: ExistingAccount[];
  pageToken?: string;
}

/** Zusammenfassung ohne E-Mail-Adressen oder andere Kontodaten. */
export interface ExistingAccountVerificationReport {
  scanned: number;
  alreadyVerified: number;
  withoutEmail: number;
  changed: number;
  pending: number;
}

/**
 * Zählt bestehende Konten oder bestätigt ihre vorhandene E-Mail-Adresse.
 *
 * Ohne `apply` bleibt der Lauf garantiert schreibfrei. Konten ohne E-Mail
 * werden übersprungen, weil für sie keine Adresse bestätigt werden kann.
 */
export async function verifyExistingAccounts(
  admin: ExistingAccountAdmin,
  options: {apply: boolean},
): Promise<ExistingAccountVerificationReport> {
  const report: ExistingAccountVerificationReport = {
    scanned: 0,
    alreadyVerified: 0,
    withoutEmail: 0,
    changed: 0,
    pending: 0,
  };
  let pageToken: string | undefined;

  do {
    const page = await admin.listUsers(1000, pageToken);
    for (const user of page.users) {
      report.scanned += 1;
      if (user.email == null) {
        report.withoutEmail += 1;
      } else if (user.emailVerified) {
        report.alreadyVerified += 1;
      } else if (options.apply) {
        await admin.markEmailVerified(user.uid);
        report.changed += 1;
      } else {
        report.pending += 1;
      }
    }
    pageToken = page.pageToken;
  } while (pageToken != null);

  return report;
}

// Hält den Kommandozeilen-Einstieg standardmäßig schreibfrei.
async function run(): Promise<void> {
  const apply = process.argv.includes("--apply");
  initializeApp({projectId});
  const auth = getAuth();
  const report = await verifyExistingAccounts(
    {
      async listUsers(maxResults, pageToken) {
        return auth.listUsers(maxResults, pageToken);
      },
      async markEmailVerified(uid) {
        await auth.updateUser(uid, {emailVerified: true});
      },
    },
    {apply},
  );

  console.log(JSON.stringify({mode: apply ? "apply" : "dry-run", ...report}));
}

const entryPoint = process.argv[1];
if (
  entryPoint != null &&
  import.meta.url === pathToFileURL(resolve(entryPoint)).href
) {
  await run();
}
