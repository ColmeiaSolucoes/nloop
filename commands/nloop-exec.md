---
description: "Execute NLoop pipeline(s) from local markdown file(s). Each file defines a feature with description, optional metadata, and implementation instructions."
argument-hint: "path/to/file.md [path/to/another.md ...] [--workflow name] [--sequential]"
---

# NLoop Exec — Run Pipeline from Markdown Files

Start one or more NLoop pipelines using local markdown files as input instead of YouTrack tickets or typed descriptions. Each `.md` file becomes a feature in the pipeline.

## Invocation

```
/nloop-exec path/to/feature.md
/nloop-exec docs/specs/dark-mode.md
/nloop-exec backlog/PROJ-42.md backlog/PROJ-43.md backlog/PROJ-44.md
/nloop-exec backlog/*.md --sequential
/nloop-exec path/to/feature.md --workflow bugfix
```

Arguments: $ARGUMENTS

## Step 1: Parse Arguments

1. Extract file paths from `$ARGUMENTS` — all arguments that end in `.md`
2. Extract optional flags:
   - `--workflow name` — force a specific workflow for all files (overrides frontmatter)
   - `--sequential` — run files one at a time (default: each file starts immediately)
   - `--dry` — show what would happen without executing (like nloop-dryrun)
3. Validate that each file exists and is readable
   - If any file not found: display "File not found: {path}" and skip it
   - If no valid files: stop with error

## Step 2: Parse Each Markdown File

For each `.md` file, extract metadata and content:

### 2.1: Check for YAML Frontmatter

If the file starts with `---`, parse the frontmatter:

```markdown
---
ticket: PROJ-42
title: Add dark mode support
workflow: default
tags: [feature, frontend]
priority: Normal
skip_brainstorm: false
---

# Feature description here...
```

**Supported frontmatter fields** (all optional):

| Field | Description | Default |
|-------|-------------|---------|
| `ticket` | Ticket ID (used as feature directory name) | Derived from filename |
| `title` | Feature title | First `#` heading in the file |
| `workflow` | Workflow to use | From `--workflow` flag or `default_workflow` in config |
| `tags` | Tags for workflow selection and skip conditions | `[]` |
| `priority` | Simulated priority | `Normal` |
| `skip_brainstorm` | Skip brainstorm phase, use file content directly | `false` |
| `skip_planning` | Skip brainstorm + plan + review, use file as plan | `false` |
| `skip_to` | Jump directly to a specific node (e.g., `task-planning`) | `null` |

### 2.2: Extract Content

- **Title**: Use `title` from frontmatter, or the first `# Heading` in the file, or the filename without extension
- **Description**: Everything after the frontmatter (or the entire file if no frontmatter)
- **Ticket ID**: Use `ticket` from frontmatter, or derive from filename:
  - `PROJ-42.md` → `PROJ-42`
  - `dark-mode.md` → `DARK-MODE`
  - `add_notifications.md` → `ADD-NOTIFICATIONS`
  - Filename is uppercased and `-`/`_` normalized to `-`

### 2.3: Determine Workflow

Priority order:
1. `--workflow` CLI flag (highest priority)
2. `workflow` from frontmatter
3. Evaluate `workflow_mapping` rules from nloop.yaml using `tags` from frontmatter
4. `default_workflow` from nloop.yaml (fallback)

## Step 3: Display Execution Plan

Before starting, show what will be executed:

```
[NLoop Exec] Execution plan:

  #  File                        Ticket ID    Workflow    Skip to
  ─  ──────────────────────────  ───────────  ──────────  ────────────
  1  backlog/PROJ-42.md          PROJ-42      default     brainstorm
  2  backlog/PROJ-43.md          PROJ-43      bugfix      brainstorm
  3  backlog/dark-mode.md        DARK-MODE    default     task-planning (skip_planning: true)

  Mode: {sequential | parallel}
  Total: {n} features

  Starting...
```

If `--dry` flag: show the plan and stop (do not execute).

## Step 4: Execute Pipelines

For each file in the execution plan:

### 4.1: Initialize Feature

Same as `/nloop-start` Step 1, but with these differences:
- **Ticket ID**: from frontmatter or derived from filename (not from YouTrack)
- **Ticket description**: the markdown file content (not from YouTrack)
- **Trigger**: set to `"exec"` (not `"manual"` or `"poll"`)
- **Source file**: store the original `.md` path in state: `state.source_file = "{path}"`

Create the feature directory:
```
.nloop/features/{TICKET_ID}/
├── state.json
├── source.md       ← copy of the original .md file
├── reviews/
└── logs/
```

Copy the original `.md` file to `features/{TICKET_ID}/source.md` for reference.

### 4.2: Handle Skip Options

Based on frontmatter skip options:

**If `skip_brainstorm: true`**:
- Use the markdown file content as `brainstorm.md` directly
- Write it to `features/{TICKET_ID}/brainstorm.md`
- Set `current_node` to the node after brainstorm (usually `plan`)

**If `skip_planning: true`**:
- Use the markdown file content as `plan.md` directly
- Write it to `features/{TICKET_ID}/plan.md`
- Skip brainstorm, plan, and review-plan nodes
- Set `current_node` to `architecture` (or next node after review-plan in the workflow)

**If `skip_to: {node}`**:
- Validate that `{node}` exists in the workflow
- Set `current_node` to `{node}`
- If the skipped nodes produced artifacts, use the markdown file content for the most relevant one:
  - skip_to `task-planning` → file becomes `spec.md`
  - skip_to `execute-tasks` → file becomes `tasks.md`
  - skip_to `code-review` → just start review (code already exists)

**If none of the skip options are set**:
- Run the full pipeline from `brainstorm`
- The markdown file content is passed as the `ticket_description` in the agent prompt

### 4.3: Start Orchestration

Continue with the standard `/nloop-start` orchestration loop (Step 2 onwards), starting from `current_node`.

The only difference is that `state.ticket_description` contains the full markdown file content instead of a YouTrack ticket description.

### 4.4: Sequential Mode

If `--sequential` flag:
1. Wait for feature N to reach a terminal state (done, escalated, failed) before starting feature N+1
2. Display progress between features:
   ```
   [NLoop Exec] Feature 1/3 completed: PROJ-42 (default workflow)
   [NLoop Exec] Starting feature 2/3: PROJ-43...
   ```

If NOT sequential (default):
1. Start all features immediately
2. Each runs its own orchestration loop
3. Display: `[NLoop Exec] Started {n} features. Use /nloop-status to monitor.`

## Step 5: Summary

After all features complete (or are started):

```
[NLoop Exec] Complete.

  #  Ticket ID    Status       PR
  ─  ───────────  ───────────  ─────────────────────
  1  PROJ-42      completed    https://github.com/...
  2  PROJ-43      completed    https://github.com/...
  3  DARK-MODE    escalated    —

  Completed: 2/3
  Escalated: 1/3

  View details: /nloop-status
```

## Examples

### Simple: one file, full pipeline
```
/nloop-exec docs/features/dark-mode.md
```
Reads the file, derives ticket ID `DARK-MODE`, runs the full default pipeline with the file content as the feature description.

### From backlog with frontmatter
```markdown
<!-- backlog/PROJ-42.md -->
---
ticket: PROJ-42
title: Add notification preferences
workflow: default
tags: [feature, frontend, backend]
---

# Notification Preferences

Users should be able to control which notifications they receive.

## Requirements
- Per-category toggle (email, in-app)
- Default: all enabled except marketing
- System preference detection
- Settings page integration

## Acceptance Criteria
- User can toggle each notification category
- Changes persist across sessions
- Marketing is opt-in by default (GDPR)
```

```
/nloop-exec backlog/PROJ-42.md
```

### Skip to implementation (you already have a spec)
```markdown
<!-- specs/PROJ-42-spec.md -->
---
ticket: PROJ-42
skip_to: task-planning
---

# Notification Preferences — Technical Specification

## Data Models
...

## API Endpoints
...

## File Changes
...
```

```
/nloop-exec specs/PROJ-42-spec.md
```
Skips brainstorm, plan, architecture — jumps straight to task planning using the spec.

### Multiple files in sequence
```
/nloop-exec backlog/PROJ-42.md backlog/PROJ-43.md backlog/PROJ-44.md --sequential
```

### Dry run to preview
```
/nloop-exec backlog/*.md --dry
```

## Error Handling

- **File not found**: Skip and warn, continue with remaining files
- **Invalid frontmatter**: Warn and use defaults, continue
- **Duplicate ticket IDs**: If `features/{ID}/` already exists, ask to resume or restart (same as nloop-start)
- **Invalid skip_to node**: Warn that node doesn't exist in workflow, start from beginning instead
- **No .md files in arguments**: Display usage help

## Notes

- The `.md` file is always copied to `features/{TICKET_ID}/source.md` for traceability
- YouTrack is NOT required for `/nloop-exec` — it works fully offline
- If YouTrack MCP is available and `ticket` frontmatter matches a real ticket ID, NLoop will still update the ticket status
- The `exec` trigger type distinguishes these features from manual or polled starts in metrics
