#!/bin/bash
# TaskCompleted hook for taro
# Runs when any teammate marks a task complete.
# Exit 0: allow completion.
# Exit 2: block completion and send feedback (printed to stdout).

set -euo pipefail

TASK_SUBJECT="${CLAUDE_HOOK_TASK_SUBJECT:-}"
TASK_DESCRIPTION="${CLAUDE_HOOK_TASK_DESCRIPTION:-}"

# If this is a Clarifier task, verify spec.md exists and is non-empty
if echo "$TASK_SUBJECT $TASK_DESCRIPTION" | grep -qi "clarif\|spec"; then
  if [[ ! -f "spec.md" ]] || [[ ! -s "spec.md" ]]; then
    echo "spec.md is missing or empty. Clarifier must write spec.md before marking complete."
    exit 2
  fi
  # Check that Open questions section is empty
  if grep -q "^- <unresolved" spec.md 2>/dev/null; then
    echo "spec.md still contains unresolved open questions. Resolve them before marking complete."
    exit 2
  fi
fi

# If this is a Planner task, verify task.md exists and is non-empty
if echo "$TASK_SUBJECT $TASK_DESCRIPTION" | grep -qi "plan\|task\.md"; then
  if [[ ! -f "task.md" ]] || [[ ! -s "task.md" ]]; then
    echo "task.md is missing or empty. Planner must write task.md before marking complete."
    exit 2
  fi
fi

# If this is a Generator task, run tests if a test runner is detectable
if echo "$TASK_SUBJECT $TASK_DESCRIPTION" | grep -qi "generat\|implement\|code"; then
  if [[ -f "package.json" ]] && command -v npm &>/dev/null; then
    if npm test --if-present 2>&1 | grep -q "FAIL\|ERROR"; then
      echo "Tests are failing. Fix failing tests before marking this task complete."
      exit 2
    fi
  elif [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]] && command -v pytest &>/dev/null; then
    if ! pytest --tb=no -q 2>&1 | grep -q "passed"; then
      echo "Pytest found failures. Fix them before marking this task complete."
      exit 2
    fi
  fi
fi

exit 0
