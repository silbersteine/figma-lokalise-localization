#!/usr/bin/env bash
# Install the skill into an agent's skills directory.
# Usage: ./scripts/install.sh [claude|cursor|<target-dir>]
#   claude  -> ~/.claude/skills           (user-level)
#   cursor  -> ./.cursor/skills           (project-level)
#   <dir>   -> any explicit directory
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$HERE/skills/figma-lokalise-localization"
TARGET_ARG="${1:-claude}"

case "$TARGET_ARG" in
  claude) DEST="$HOME/.claude/skills" ;;
  cursor) DEST="$PWD/.cursor/skills" ;;
  *)      DEST="$TARGET_ARG" ;;
esac

if [ ! -f "$SRC/SKILL.md" ]; then
  echo "error: canonical skill not found at $SRC" >&2
  exit 1
fi

mkdir -p "$DEST"
cp -r "$SRC" "$DEST/"
echo "Installed 'figma-lokalise-localization' -> $DEST/figma-lokalise-localization"
echo "Reminder: connect the Figma and Lokalise MCP servers (see docs/mcp-setup.md)."
