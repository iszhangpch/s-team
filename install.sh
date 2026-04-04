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
SETTINGS_FILE="$TARGET/.claude/settings.json"

mkdir -p "$AGENTS_DST" "$COMMANDS_DST"

# Enable agent teams in target project settings
if [[ -f "$SETTINGS_FILE" ]]; then
  if python3 -c "import json,sys; d=json.load(open('$SETTINGS_FILE')); sys.exit(0 if d.get('env',{}).get('CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS')=='1' else 1)" 2>/dev/null; then
    echo "  [skip] agent teams already enabled in settings.json"
  else
    python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    d = json.load(f)
d.setdefault('env', {})['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'] = '1'
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(d, f, indent=2)
print('  [ok]   enabled CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS in settings.json')
"
  fi
else
  echo '{"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}}' | python3 -m json.tool > "$SETTINGS_FILE"
  echo "  [ok]   created settings.json with agent teams enabled"
fi

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
CMD_SRC="$SCRIPT_DIR/.claude/commands/steam.md"
CMD_DST="$COMMANDS_DST/steam.md"
if [[ -f "$CMD_DST" ]]; then
  echo "  [skip] commands/steam.md already exists (use --force to overwrite)"
else
  cp "$CMD_SRC" "$CMD_DST"
  echo "  [ok]   commands/steam.md"
fi

# Handle --force flag
if [[ "${2:-}" == "--force" ]]; then
  for f in "$AGENTS_SRC"/*.md; do
    name="$(basename "$f")"
    cp "$f" "$AGENTS_DST/$name"
    echo "  [force] agents/$name"
  done
  cp "$CMD_SRC" "$CMD_DST"
  echo "  [force] commands/steam.md"
fi

echo ""
echo "Done. In your project, run: /steam <task description>"
