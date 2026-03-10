#!/bin/bash
set -euo pipefail

# Nur in Remote-Umgebungen (Claude Code im Web) ausführen
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_DIR="$HOME/flutter"
FLUTTER_BIN="$FLUTTER_DIR/bin/flutter"

# Flutter installieren, falls nicht vorhanden
if ! command -v flutter &>/dev/null && [ ! -f "$FLUTTER_BIN" ]; then
  echo "Installiere Flutter SDK (stable)..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
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
