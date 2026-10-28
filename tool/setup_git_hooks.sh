#!/bin/sh
# Aktiviert die versionierten Git-Hooks aus .githooks/ (einmalig pro Clone).
git config core.hooksPath .githooks
git update-index --chmod=+x .githooks/pre-commit .githooks/pre-push 2>/dev/null || true
chmod +x .githooks/pre-commit .githooks/pre-push
echo "Git-Hooks aktiviert (core.hooksPath=.githooks)."
