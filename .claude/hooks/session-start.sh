#!/bin/bash
set -euo pipefail

# Versionierte Git-Hooks (dart format, flutter analyze) in jedem Klon aktivieren;
# core.hooksPath ist lokale Git-Konfiguration und kommt nicht mit dem Klon mit.
git -C "${CLAUDE_PROJECT_DIR:-.}" config core.hooksPath .githooks 2>/dev/null || true

# Nur in Remote-Umgebungen (Claude Code im Web) ausführen
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_DIR="$HOME/flutter"
FLUTTER_BIN="$FLUTTER_DIR/bin/flutter"

# Flutter-Version wie in CI (einzige Quelle: flutter-version in der Workflow-
# Datei). Der stable-Branch wandert weiter, neuere Versionen melden andere
# Lints (flutter analyze bricht Pre-Push ab) und ändern pubspec.lock.
FLUTTER_VERSION="$(grep -m1 -oE 'flutter-version: *[0-9.]+' \
  "$CLAUDE_PROJECT_DIR/.github/workflows/flutter-tests.yml" \
  | grep -oE '[0-9.]+$' || true)"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.1}"

if [ ! -f "$FLUTTER_BIN" ]; then
  echo "Installiere Flutter SDK $FLUTTER_VERSION..."
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" \
    --depth 1 "$FLUTTER_DIR"
elif [ "$(git -C "$FLUTTER_DIR" describe --tags --exact-match 2>/dev/null || true)" != "$FLUTTER_VERSION" ]; then
  # Vorhandene Installation (z. B. früherer stable-Klon) auf die Version heben.
  echo "Stelle Flutter SDK auf $FLUTTER_VERSION um..."
  git -C "$FLUTTER_DIR" fetch --depth 1 origin tag "$FLUTTER_VERSION"
  git -C "$FLUTTER_DIR" checkout --quiet "$FLUTTER_VERSION"
fi

# Flutter zum PATH hinzufügen (persistent für die gesamte Session)
if [ -d "$FLUTTER_DIR/bin" ]; then
  echo "export PATH=\"\$PATH:$FLUTTER_DIR/bin\"" >> "$CLAUDE_ENV_FILE"
  export PATH="$PATH:$FLUTTER_DIR/bin"
fi

# Dart/Flutter-Artefakte cachen (nur Linux-Desktop, ohne mobile/web Plattformen)
flutter precache --no-android --no-ios --no-macos --no-web --no-windows --no-fuchsia 2>/dev/null || true

# Pub-Abhängigkeiten installieren
cd "$CLAUDE_PROJECT_DIR"
flutter pub get
