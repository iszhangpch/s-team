#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $0 <target-project-path>"
  echo ""
  echo "Installs s-team agents and command into the target project's .claude/ directory."
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

TARGET="$1"

if [[ ! -d "$TARGET" ]]; then
  echo "Error: target directory '$TARGET' does not exist."
  exit 1
fi

AGENTS_SRC="$SCRIPT_DIR/.claude/agents"
AGENTS_DST="$TARGET/.claude/agents"
COMMANDS_DST="$TARGET/.claude/commands"

mkdir -p "$AGENTS_DST" "$COMMANDS_DST"

# Copy agents
for f in "$AGENTS_SRC"/*.md; do
  name="$(basename "$f")"
  if [[ -f "$AGENTS_DST/$name" ]]; then
    echo "  [skip] agents/$name already exists (use --force to overwrite)"
  else
    cp "$f" "$AGENTS_DST/$name"
    echo "  [ok]   agents/$name"
  fi
done

# Copy command
CMD_SRC="$SCRIPT_DIR/.claude/commands/s-team.md"
CMD_DST="$COMMANDS_DST/s-team.md"
if [[ -f "$CMD_DST" ]]; then
  echo "  [skip] commands/s-team.md already exists (use --force to overwrite)"
else
  cp "$CMD_SRC" "$CMD_DST"
  echo "  [ok]   commands/s-team.md"
fi

# Handle --force flag
if [[ "${2:-}" == "--force" ]]; then
  for f in "$AGENTS_SRC"/*.md; do
    name="$(basename "$f")"
    cp "$f" "$AGENTS_DST/$name"
    echo "  [force] agents/$name"
  done
  cp "$CMD_SRC" "$CMD_DST"
  echo "  [force] commands/s-team.md"
fi

echo ""
echo "Done. In your project, run: /s-team <task description>"
