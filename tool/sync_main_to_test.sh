#!/usr/bin/env bash
# Merge main into test without losing test-only changes or forcing remote history.
set -euo pipefail

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# Refetch before each attempt so a concurrent test push is merged, never replaced.
for attempt in 1 2 3; do
  git fetch origin main test
  git switch --detach origin/test
  if git merge-base --is-ancestor origin/main HEAD; then
    echo "changed=false" >> "$GITHUB_OUTPUT"
    echo "sha=$(git rev-parse HEAD)" >> "$GITHUB_OUTPUT"
    exit 0
  fi

  if ! git merge --no-edit origin/main; then
    echo "::error::Merge conflict: main could not be merged into test. Resolve the conflict manually; test has not been changed."
    git diff --name-only --diff-filter=U
    git merge --abort
    exit 1
  fi

  if git push origin HEAD:refs/heads/test; then
    echo "changed=true" >> "$GITHUB_OUTPUT"
    echo "sha=$(git rev-parse HEAD)" >> "$GITHUB_OUTPUT"
    exit 0
  fi
  echo "Remote test changed or push rejected; retry $attempt/3."
done

echo "::error::Could not update test after three attempts. Check branch protection and concurrent pushes."
exit 1
