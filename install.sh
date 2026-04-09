#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $0 <target-project-path> [--force]"
  echo ""
  echo "Installs taro agents and command into the target project's .claude/ directory."
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

TARGET="$1"
FORCE="${2:-}"

if [[ ! -d "$TARGET" ]]; then
  echo "Error: target directory '$TARGET' does not exist."
  exit 1
fi

# ── Check superpowers prerequisite ────────────────────────────────────────────

GLOBAL_SETTINGS="$HOME/.claude/settings.json"
SUPERPOWERS_INSTALLED=false

if [[ -f "$GLOBAL_SETTINGS" ]]; then
  if python3 -c "
import json, sys
d = json.load(open('$GLOBAL_SETTINGS'))
plugins = d.get('enabledPlugins', {})
sys.exit(0 if any('superpowers' in k for k in plugins) else 1)
" 2>/dev/null; then
    SUPERPOWERS_INSTALLED=true
  fi
fi

# Locate superpowers install path
SUPERPOWERS_SRC=""
if [[ "$SUPERPOWERS_INSTALLED" == "true" ]]; then
  SUPERPOWERS_SRC=$(python3 -c "
import json
d = json.load(open('$HOME/.claude/plugins/installed_plugins.json'))
for key, entries in d.get('plugins', {}).items():
    if 'superpowers' in key:
        print(entries[-1]['installPath'])
        break
" 2>/dev/null || echo "")
fi

if [[ -z "$SUPERPOWERS_SRC" ]] || [[ ! -d "$SUPERPOWERS_SRC" ]]; then
  echo ""
  echo "  [error] superpowers plugin not found."
  echo ""
  echo "  Please install it first inside Claude Code:"
  echo "    /plugin marketplace add obra/superpowers-marketplace"
  echo "    /plugin install superpowers@superpowers-marketplace"
  echo ""
  echo "  Then re-run this script."
  exit 1
fi

echo "  [ok]   superpowers found at $SUPERPOWERS_SRC"

# ── Paths ─────────────────────────────────────────────────────────────────────

AGENTS_SRC="$SCRIPT_DIR/.claude/agents"
AGENTS_DST="$TARGET/.claude/agents"
COMMANDS_DST="$TARGET/.claude/commands"
HOOKS_SRC="$SCRIPT_DIR/.claude/hooks"
HOOKS_DST="$TARGET/.claude/hooks"
TEMPLATES_SRC="$SCRIPT_DIR/.claude/templates"
TEMPLATES_DST="$TARGET/.claude/templates"
SETTINGS_FILE="$TARGET/.claude/settings.json"

mkdir -p "$AGENTS_DST" "$COMMANDS_DST" "$HOOKS_DST" "$TEMPLATES_DST"

# ── Enable agent teams in target project settings ─────────────────────────────

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

# ── Register task-completed hook in settings.json ─────────────────────────────

python3 -c "
import json, os
settings_file = '$SETTINGS_FILE'
hook_cmd = 'bash .claude/hooks/task-completed.sh'

with open(settings_file) as f:
    d = json.load(f)

hooks = d.setdefault('hooks', {})
tc_hooks = hooks.setdefault('TaskCompleted', [])

already = any(
    hook.get('command') == hook_cmd
    for entry in tc_hooks
    for hook in entry.get('hooks', [])
)

if already:
    print('  [skip] TaskCompleted hook already registered in settings.json')
else:
    tc_hooks.append({'hooks': [{'type': 'command', 'command': hook_cmd}]})
    with open(settings_file, 'w') as f:
        json.dump(d, f, indent=2)
    print('  [ok]   registered TaskCompleted hook in settings.json')
"

# ── Copy taro agents ─────────────────────────────────────────────────────────

for f in "$AGENTS_SRC"/*.md; do
  name="$(basename "$f")"
  if [[ -f "$AGENTS_DST/$name" ]] && [[ "$FORCE" != "--force" ]]; then
    echo "  [skip] agents/$name already exists (use --force to overwrite)"
  else
    cp "$f" "$AGENTS_DST/$name"
    echo "  [ok]   agents/$name"
  fi
done

# ── Copy taro command ─────────────────────────────────────────────────────────

CMD_SRC="$SCRIPT_DIR/.claude/commands/taro.md"
CMD_DST="$COMMANDS_DST/taro.md"
if [[ -f "$CMD_DST" ]] && [[ "$FORCE" != "--force" ]]; then
  echo "  [skip] commands/taro.md already exists (use --force to overwrite)"
else
  cp "$CMD_SRC" "$CMD_DST"
  echo "  [ok]   commands/taro.md"
fi

# ── Copy taro hooks ──────────────────────────────────────────────────────────

for f in "$HOOKS_SRC"/*.sh; do
  name="$(basename "$f")"
  if [[ -f "$HOOKS_DST/$name" ]] && [[ "$FORCE" != "--force" ]]; then
    echo "  [skip] hooks/$name already exists (use --force to overwrite)"
  else
    cp "$f" "$HOOKS_DST/$name"
    chmod +x "$HOOKS_DST/$name"
    echo "  [ok]   hooks/$name"
  fi
done

# ── Copy taro templates ──────────────────────────────────────────────────────

for f in "$TEMPLATES_SRC"/*.tpl; do
  name="$(basename "$f")"
  if [[ -f "$TEMPLATES_DST/$name" ]] && [[ "$FORCE" != "--force" ]]; then
    echo "  [skip] templates/$name already exists (use --force to overwrite)"
  else
    cp "$f" "$TEMPLATES_DST/$name"
    echo "  [ok]   templates/$name"
  fi
done


echo ""
echo "Done. In your project, run: /taro <task description>"
