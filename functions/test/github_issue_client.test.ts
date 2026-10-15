import assert from "node:assert/strict";
import test from "node:test";

import { GitHubIssueClient } from "../src/feedback/github_issue_client.js";

test("creates an issue only in the configured repository", async () => {
  let requestedUrl = "";
  let requestedBody = "";
  const client = new GitHubIssueClient({
    owner: "DennisAdamski",
    repository: "DSA_HeroApp",
    token: "secret",
    fetcher: async (input, init) => {
      requestedUrl = input.toString();
      requestedBody = init?.body?.toString() ?? "";
      return new Response(JSON.stringify({ number: 42, html_url: "https://github.test/issues/42" }), {
        status: 201,
        headers: { "content-type": "application/json" },
      });
    },
  });

  const result = await client.createIssue("Titel", "Text", ["bug"], "feedback:abc");

  assert.equal(requestedUrl, "https://api.github.com/repos/DennisAdamski/DSA_HeroApp/issues");
  assert.deepEqual(JSON.parse(requestedBody), { title: "Titel", body: "Text", labels: ["bug"] });
  assert.deepEqual(result, { number: 42, url: "https://github.test/issues/42" });
});

test("marks transport failures uncertain but treats HTTP rejection as definite", async () => {
  const timeoutClient = new GitHubIssueClient({
    owner: "DennisAdamski",
    repository: "DSA_HeroApp",
    token: "secret",
    fetcher: async () => { throw new TypeError("network failed"); },
  });
  await assert.rejects(
    () => timeoutClient.createIssue("Titel", "Text", ["bug"], "feedback:abc"),
    (error: unknown) => (error as { uncertain?: boolean }).uncertain === true,
  );

  const rejectedClient = new GitHubIssueClient({
    owner: "DennisAdamski",
    repository: "DSA_HeroApp",
    token: "secret",
    fetcher: async () => new Response("forbidden", { status: 403 }),
  });
  await assert.rejects(
    () => rejectedClient.createIssue("Titel", "Text", ["bug"], "feedback:abc"),
    (error: unknown) => (error as { uncertain?: boolean }).uncertain !== true,
  );
});
