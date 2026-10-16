export const feedbackSurfaces = [
  "heroSelection",
  "overview",
  "talents",
  "combat",
  "magic",
  "inventory",
  "notes",
  "travelLog",
  "companions",
  "group",
  "play",
  "advancement",
  "settings",
  "catalog",
  "other",
] as const;

export type FeedbackSurface = (typeof feedbackSurfaces)[number];
export type FeedbackKind = "bug" | "feature" | "rules";

export interface FeedbackBaseMetadata {
  appVersion: string;
  buildNumber: string;
  commit: string;
  builtAt: string;
  platform: string;
}

export interface BugDiagnostics {
  operatingSystem: string;
  operatingSystemVersion: string;
  locale: string;
  viewportWidth: number;
  viewportHeight: number;
  devicePixelRatio: number;
  layoutClass: "compact" | "tabletPortrait" | "tabletLandscape" | "desktopWide";
  interfaceVariant: "codex" | "kartograph";
  brightness: "light" | "dark";
  tableMode: "automatic" | "table" | "cards";
  firebaseAvailable: boolean;
  authenticated: boolean;
}

interface FeedbackSubmissionBase {
  schemaVersion: 1;
  requestId: string;
  kind: FeedbackKind;
  title: string;
  surface: FeedbackSurface;
  metadata: FeedbackBaseMetadata;
}

export interface BugFeedbackSubmission extends FeedbackSubmissionBase {
  kind: "bug";
  actualBehavior: string;
  expectedBehavior: string;
  reproductionSteps?: string;
  diagnostics?: BugDiagnostics;
}

export interface FeatureFeedbackSubmission extends FeedbackSubmissionBase {
  kind: "feature";
  problem: string;
  desiredBehavior: string;
}

export interface RulesFeedbackSubmission extends FeedbackSubmissionBase {
  kind: "rules";
  question: string;
  source?: string;
  interpretation?: string;
}

export type FeedbackSubmission =
  | BugFeedbackSubmission
  | FeatureFeedbackSubmission
  | RulesFeedbackSubmission;

export type FeedbackStatus = "created" | "processing" | "uncertain" | "failed";

export interface FeedbackResult {
  requestId: string;
  status: FeedbackStatus;
  issueNumber?: number;
  issueUrl?: string;
  code?: string;
}
