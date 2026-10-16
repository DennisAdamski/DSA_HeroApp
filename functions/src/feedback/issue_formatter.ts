import type { FeedbackSubmission } from "./types.js";

export interface FormattedIssue {
  title: string;
  body: string;
  labels: string[];
}

/** Creates the fixed public GitHub representation of a validated submission. */
export function formatIssue(
  submission: FeedbackSubmission,
  options: { marker: string; testMode: boolean },
): FormattedIssue {
  const lines = submission.kind === "bug"
    ? formatBug(submission)
    : submission.kind === "feature"
      ? formatFeature(submission)
      : formatRules(submission);
  const base = submission.metadata;
  lines.push(
    "## App-Kontext",
    `- Bereich: ${surfaceLabel(submission.surface)}`,
    `- Version: ${base.appVersion}+${base.buildNumber}`,
    `- Build: ${base.commit || "lokal"}`,
    `- Bauzeit: ${base.builtAt || "unbekannt"}`,
    `- Plattform: ${base.platform}`,
  );
  if (submission.kind === "bug" && submission.diagnostics != null) {
    const d = submission.diagnostics;
    lines.push(
      "## Diagnose",
      `- Betriebssystem: ${d.operatingSystem} ${d.operatingSystemVersion}`.trim(),
      `- Sprache: ${d.locale}`,
      `- Fenster: ${d.viewportWidth} × ${d.viewportHeight} @ ${d.devicePixelRatio}`,
      `- Layout: ${d.layoutClass}`,
      `- Oberfläche: ${d.interfaceVariant}, ${d.brightness}, ${d.tableMode}`,
      `- Firebase verfügbar: ${d.firebaseAvailable ? "ja" : "nein"}`,
      `- Angemeldet: ${d.authenticated ? "ja" : "nein"}`,
    );
  }
  lines.push(`<!-- ${options.marker} -->`);
  const kindLabel = submission.kind === "bug"
    ? "bug"
    : submission.kind === "feature"
      ? "enhancement"
      : "question";
  return {
    title: neutralizeMentions(submission.title),
    body: neutralizeMentions(lines.join("\n\n")),
    labels: [
      "in-app-feedback",
      kindLabel,
      ...(options.testMode ? ["feedback-test"] : []),
    ],
  };
}

function formatBug(submission: Extract<FeedbackSubmission, { kind: "bug" }>): string[] {
  return [
    "## Tatsächliches Verhalten",
    submission.actualBehavior,
    "## Erwartetes Verhalten",
    submission.expectedBehavior,
    ...(submission.reproductionSteps == null
      ? []
      : ["## Schritte zur Reproduktion", submission.reproductionSteps]),
  ];
}

function formatFeature(submission: Extract<FeedbackSubmission, { kind: "feature" }>): string[] {
  return [
    "## Zu lösendes Problem",
    submission.problem,
    "## Gewünschtes Verhalten",
    submission.desiredBehavior,
  ];
}

function formatRules(submission: Extract<FeedbackSubmission, { kind: "rules" }>): string[] {
  return [
    "## Regelfrage",
    submission.question,
    ...(submission.source == null ? [] : ["## Regelwerk/Fundstelle", submission.source]),
    ...(submission.interpretation == null ? [] : ["## Eigene Auslegung", submission.interpretation]),
  ];
}

function neutralizeMentions(value: string): string {
  return value.replace(/@(?=[\p{L}\p{N}_-])/gu, "@\u200b");
}

function surfaceLabel(surface: FeedbackSubmission["surface"]): string {
  return {
    heroSelection: "Heldenauswahl",
    overview: "Übersicht",
    talents: "Talente",
    combat: "Kampf",
    magic: "Magie",
    inventory: "Inventar",
    notes: "Notizen",
    travelLog: "Reisebericht",
    companions: "Begleiter",
    group: "Gruppe",
    play: "Spielmodus",
    advancement: "Entwicklung",
    settings: "Einstellungen",
    catalog: "Katalogverwaltung",
    other: "Sonstiges",
  }[surface];
}
