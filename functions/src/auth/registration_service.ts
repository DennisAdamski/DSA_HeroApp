export interface RegistrationTicketStore {
  allowAttempt(
    key: string,
    maxAttempts: number,
    now: Date,
    windowMs: number,
  ): Promise<boolean>;
  issueTicket(email: string, expiresAt: Date): Promise<void>;
  consumeTicket(email: string, now: Date): Promise<boolean>;
}

export interface RegistrationInviteOptions {
  verifyKeyword(keyword: string): Promise<boolean>;
  ticketTtlMs?: number;
  attemptWindowMs?: number;
  maxAttempts?: number;
}

export interface RegistrationInviteRequest {
  email: string;
  keyword: string;
  callerKey: string;
  now?: Date;
}

/** Stable service error that can be mapped without exposing secret details. */
export class RegistrationServiceError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = "RegistrationServiceError";
  }
}

/** Issues and atomically consumes short-lived, email-bound registration tickets. */
export class RegistrationInviteService {
  private readonly ticketTtlMs: number;
  private readonly attemptWindowMs: number;
  private readonly maxAttempts: number;

  constructor(
    private readonly store: RegistrationTicketStore,
    private readonly options: RegistrationInviteOptions,
  ) {
    this.ticketTtlMs = options.ticketTtlMs ?? 10 * 60 * 1000;
    this.attemptWindowMs = options.attemptWindowMs ?? 60 * 60 * 1000;
    this.maxAttempts = options.maxAttempts ?? 5;
  }

  /** Validates an invite keyword and creates a single-use ticket. */
  async issue(request: RegistrationInviteRequest): Promise<void> {
    const email = normalizeEmail(request.email);
    const callerKey = request.callerKey.trim();
    const now = request.now ?? new Date();
    if (callerKey.length === 0) {
      throw new RegistrationServiceError("CALLER_REQUIRED");
    }

    const callerAllowed = await this.store.allowAttempt(
      `caller:${callerKey}`,
      this.maxAttempts,
      now,
      this.attemptWindowMs,
    );
    const emailAllowed = await this.store.allowAttempt(
      `email:${email}`,
      this.maxAttempts,
      now,
      this.attemptWindowMs,
    );
    if (!callerAllowed || !emailAllowed) {
      throw new RegistrationServiceError("RATE_LIMITED");
    }

    const keywordValid = await this.options.verifyKeyword(request.keyword);
    if (!keywordValid) {
      throw new RegistrationServiceError("INVITE_INVALID");
    }
    const expiresAt = new Date(now.getTime() + this.ticketTtlMs);
    await this.store.issueTicket(email, expiresAt);
  }

  /** Consumes the valid ticket for an email exactly once. */
  async consume(email: string, now = new Date()): Promise<boolean> {
    return this.store.consumeTicket(normalizeEmail(email), now);
  }
}

/** Normalizes and validates an address before it becomes a ticket key. */
export function normalizeEmail(raw: string): string {
  const email = raw.trim().toLowerCase();
  const simpleEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (email.length > 254 || !simpleEmail.test(email)) {
    throw new RegistrationServiceError("EMAIL_INVALID");
  }
  return email;
}
