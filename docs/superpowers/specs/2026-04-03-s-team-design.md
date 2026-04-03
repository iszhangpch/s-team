# s-team Design Spec

**Date:** 2026-04-03
**Status:** Approved

## Overview

s-team is an out-of-the-box Claude Code agent team scaffold for software development workflows. It provides four specialized roles — Clarifier, Planner, Generator, Evaluator — coordinated via Claude Code's native agent teams capability. The project is a template: `cd` into it, run `./s-team "<task>"`, and a structured multi-agent team starts working.

The core assets are role prompts and output templates, not orchestration code. The shell entry point is a thin wrapper for tmux layout and environment setup.

## Architecture

### Project Structure

```
s-team/
├── CLAUDE.md                        # Project context + team startup instructions
├── s-team                           # Entry script (tmux layout + claude launch)
├── settings.json                    # Enables CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
├── .claude/
│   ├── agents/
│   │   ├── clarifier.md             # Clarifier role definition (uses brainstorming)
│   │   ├── planner.md               # Planner role definition
│   │   ├── generator.md             # Generator role definition
│   │   └── evaluator.md             # Evaluator role definition
│   ├── hooks/
│   │   └── task-completed.sh        # Evaluator quality gate hook
│   └── templates/
│       ├── spec.md.tpl              # Clarifier output template
│       └── task.md.tpl              # Planner output template
└── docs/
    └── superpowers/specs/           # Design documents
```

### tmux Layout

```
┌─────────────────────────┬──────────────┐
│                         │              │
│   Active agent pane     │   Pipeline   │
│   (Clarifier / Planner  │   status     │
│    / Generator output)  │   pane       │
│                         │              │
└─────────────────────────┴──────────────┘
```

`teammateMode: "tmux"` — split-pane mode so users can click into any teammate's pane directly.

## Roles

### Clarifier

**Responsibility:** Align with the user on requirements and produce `spec.md`.

**Process:** Uses the superpowers brainstorming skill protocol:
- Ask one question at a time
- Prefer multiple-choice questions
- Propose 2–3 approaches with trade-offs before settling
- Present design sections and get approval incrementally

**Input:** User's natural language task description

**Output:** `spec.md` (fixed template, see Templates section)

**Interaction:** Runs in its own tmux pane. User can interact directly by clicking the pane. This is the only stage that requires sustained human dialogue.

### Planner

**Responsibility:** Read the codebase and `spec.md`, produce a concrete implementation plan in `task.md`.

**Input:** `spec.md` + existing codebase (read-only exploration)

**Output:** `task.md` (fixed template, see Templates section)

**Interaction:** Autonomous. Review node after completion — user presses Enter to continue or E to edit `task.md`.

### Generator

**Responsibility:** Implement code changes according to `task.md`.

**Input:** `task.md`

**Output:** Code changes (files, tests)

**Interaction:** Autonomous. Review node after completion — user presses Enter to continue or E to review diffs.

### Evaluator

**Responsibility:** Review each stage's output and enforce quality gates. Does not produce code; only approves, patches minor issues, or escalates.

**Trigger:** `TaskCompleted` hook fires automatically when any teammate marks a task complete.

**Decision tiers:**
- **Minor issues** (typos, formatting, small gaps): auto-fix and re-approve
- **Major issues** (wrong direction, missing requirements, broken tests): exit code 2 (blocks completion), send feedback to the relevant teammate for rework
- **Escalation** (repeated failures, ambiguous requirements): pause and surface to user

**Interaction:** Runs in background; escalations appear as pauses with explanation.

## Flow

```
User: ./s-team "build a login feature"
  │
  ▼
s-team script
  - Sets up tmux layout (left main, right status)
  - Writes initial task to shared task list
  - Launches claude (team lead)
  │
  ▼
Lead spawns Clarifier teammate
  - Clarifier follows brainstorming protocol with user
  - Outputs spec.md
  - Marks task complete → Evaluator hook fires
  │
  ▼  [Review node: Enter to continue / E to edit spec.md]
  │
Lead spawns Planner teammate
  - Reads codebase + spec.md
  - Outputs task.md
  - Marks task complete → Evaluator hook fires
  │
  ▼  [Review node: Enter to continue / E to edit task.md]
  │
Lead spawns Generator teammate
  - Implements code per task.md
  - Marks tasks complete → Evaluator hook fires per task
  │
  ▼  [Review node: Enter to continue / E to review diffs]
  │
Done
```

Escape hatch: Ctrl+C at any point, then `./s-team resume --from <stage>` to restart from a specific stage using existing files.

## Templates

### spec.md

```markdown
# Spec: <feature name>

## Goal
<one paragraph describing what we're building and why>

## Scope
### In scope
- <item>

### Out of scope
- <item>

## Requirements
### Functional
- <requirement>

### Non-functional
- <performance, security, accessibility constraints>

## Open questions
- <unresolved items>

## Approved approach
<which option was chosen and why>
```

### task.md

```markdown
# Task Plan: <feature name>

## Context
<brief summary of relevant existing code, patterns to follow>

## Tasks

### Task 1: <name>
**Files:** `src/...`
**Description:** <what to implement>
**Acceptance criteria:**
- <criterion>

### Task 2: <name>
...

## Dependencies
<task ordering and blockers>

## Testing plan
<what tests to write and how to verify>
```

## Configuration

### settings.json

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "tmux"
}
```

### Requirements

- Claude Code v2.1.32+
- tmux installed and available in PATH
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` enabled (handled by settings.json)

## Human-in-the-Loop Model

| Stage | Human involvement |
|-------|------------------|
| Clarifier | Active dialogue (clicks into Clarifier pane) |
| After Clarifier | Review node: confirm or edit spec.md |
| After Planner | Review node: confirm or edit task.md |
| After Generator | Review node: confirm or review diffs |
| Evaluator escalation | Paused with explanation, user decides |
| Any stage | Ctrl+C to interrupt, `resume --from <stage>` to restart |

## Out of Scope (for now)

- Multi-language support or opinionated project structure
- Remote execution or cloud sync
- GUI beyond tmux split panes
- Automated git commits or PR creation
