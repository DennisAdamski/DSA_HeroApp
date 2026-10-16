import type { FeedbackIssueClient } from "./submission_service.js";

/** Minimal GitHub Issues REST client with a fixed repository boundary. */
export class GitHubIssueClient implements FeedbackIssueClient {
  private readonly fetcher: typeof fetch;

  constructor(private readonly options: {
    owner: string;
    repository: string;
    token: string;
    fetcher?: typeof fetch;
    timeoutMs?: number;
  }) {
    this.fetcher = options.fetcher ?? fetch;
  }

  /** Creates one issue; transport failures remain ambiguous to prevent retries. */
  async createIssue(
    title: string,
    body: string,
    labels: string[],
    _marker: string,
  ): Promise<{ number: number; url: string }> {
    const response = await this.request(
      `https://api.github.com/repos/${this.options.owner}/${this.options.repository}/issues`,
      {
        method: "POST",
        body: JSON.stringify({ title, body, labels }),
      },
      true,
    );
    const json = await response.json() as { number?: unknown; html_url?: unknown };
    if (typeof json.number !== "number" || typeof json.html_url !== "string") {
      throw new GitHubIssueError(false);
    }
    return { number: json.number, url: json.html_url };
  }

  /** Searches the configured repository for the server-generated marker. */
  async findByMarker(marker: string): Promise<{ number: number; url: string } | null> {
    const query = encodeURIComponent(`repo:${this.options.owner}/${this.options.repository} "${marker}" in:body type:issue`);
    const response = await this.request(
      `https://api.github.com/search/issues?q=${query}&per_page=1`,
      { method: "GET" },
      false,
    );
    const json = await response.json() as {
      items?: Array<{ number?: unknown; html_url?: unknown }>;
    };
    const item = json.items?.[0];
    if (item == null) return null;
    if (typeof item.number !== "number" || typeof item.html_url !== "string") return null;
    return { number: item.number, url: item.html_url };
  }

  private async request(
    url: string,
    init: RequestInit,
    postMayHaveSucceeded: boolean,
  ): Promise<Response> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.options.timeoutMs ?? 8_000);
    try {
      const response = await this.fetcher(url, {
        ...init,
        signal: controller.signal,
        headers: {
          accept: "application/vnd.github+json",
          authorization: `Bearer ${this.options.token}`,
          "content-type": "application/json",
          "x-github-api-version": "2022-11-28",
        },
      });
      if (!response.ok) throw new GitHubIssueError(false);
      return response;
    } catch (error) {
      if (error instanceof GitHubIssueError) throw error;
      throw new GitHubIssueError(postMayHaveSucceeded);
    } finally {
      clearTimeout(timeout);
    }
  }
}

/** Carries only whether a failed POST may already have created an issue. */
export class GitHubIssueError extends Error {
  constructor(readonly uncertain: boolean) {
    super(uncertain ? "GITHUB_OUTCOME_UNCERTAIN" : "GITHUB_REJECTED");
  }
}
