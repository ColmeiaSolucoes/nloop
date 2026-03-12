---
name: nloop-status
description: >
  Display the NLoop dashboard showing status of all features in the pipeline.
  Use /nloop-status for overview or /nloop-status TICKET-ID for detailed view.
user-invocable: true
---

# NLoop Status Dashboard

You render a terminal dashboard showing the status of all features in the NLoop pipeline.

## Invocation

```
/nloop-status              # Overview of all features
/nloop-status TICKET-ID    # Detailed view of a specific feature
```

## Overview Mode (no arguments)

### Step 1: Scan Features

1. List all directories in `.nloop/features/`
2. For each directory, read `state.json`
3. Group features by status: `in_progress`, `escalated`, `pending`, `completed`, `failed`

### Step 2: Render Dashboard

Display the following dashboard:

```
╔══════════════════════════════════════════════════════════════════════╗
║                       NLOOP STATUS DASHBOARD                        ║
║                       {current date and time}                        ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  ACTIVE ({count})                                                    ║
║  ─────────────                                                       ║
║  {TICKET-ID}  {title (truncated to 30 chars)}  {progress_bar} {node} ║
║  {TICKET-ID}  {title (truncated to 30 chars)}  {progress_bar} {node} ║
║                                                                      ║
║  ESCALATED ({count})                                                 ║
║  ──────────────                                                      ║
║  {TICKET-ID}  {title}  ⚠ {escalation.reason} at {escalation.node}  ║
║                                                                      ║
║  WAITING APPROVAL ({count})                                          ║
║  ───────────────────────                                             ║
║  {TICKET-ID}  {title}  [{priority}]                                 ║
║                                                                      ║
║  COMPLETED (last 5)                                                  ║
║  ──────────────────                                                  ║
║  {TICKET-ID}  {title}  ✓ PR: {pr.url}                              ║
║                                                                      ║
║  STATS                                                               ║
║  ─────                                                               ║
║  Total: {n} | Active: {n} | Completed: {n} | Escalated: {n}        ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Progress Bar Logic

The workflow has these ordered nodes for progress calculation:
```
brainstorm → plan → review-plan → architecture → review-spec → brainstorm-refinement → task-planning → execute-tasks → code-review → unit-testing → qa-testing → create-pr → done
```
Total: 13 steps. Calculate progress as `(current_node_index / 13)`.

Progress bar format: `██████░░░░░░` (12 chars, filled proportionally)

For `execute-tasks` node, show task progress: `Tasks: {completed}/{total}`

For review nodes, show round: `review-plan (2/4)`

## Detail Mode (/nloop-status TICKET-ID)

### Step 1: Read State

Read `.nloop/features/{TICKET-ID}/state.json`

### Step 2: Render Detail View

```
╔══════════════════════════════════════════════════════════════════════╗
║  FEATURE: {TICKET-ID} — {ticket_title}                              ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Status: {status}          Workflow: {workflow}                      ║
║  Started: {started_at}     Updated: {updated_at}                    ║
║  Current Node: {current_node}                                        ║
║  Trigger: {trigger}                                                  ║
║                                                                      ║
║  REVIEW ROUNDS                                                       ║
║  ─────────────                                                       ║
║  Plan: {n}/4    Spec: {n}/4    Code: {n}/4                          ║
║                                                                      ║
║  TASKS                                                               ║
║  ─────                                                               ║
║  Total: {n}  Completed: {n}  In Progress: {n}  Failed: {n}         ║
║                                                                      ║
║  PR                                                                  ║
║  ──                                                                  ║
║  URL: {pr.url or "Not created yet"}                                 ║
║  Branch: {pr.branch or "N/A"}                                       ║
║                                                                      ║
║  HISTORY                                                             ║
║  ───────                                                             ║
║  {timestamp}  {node} → {status} ({agent}: {action})                 ║
║  {timestamp}  {node} → {status} ({agent}: {action})                 ║
║  ...                                                                 ║
║                                                                      ║
║  ARTIFACTS                                                           ║
║  ─────────                                                           ║
║  [✓] brainstorm.md     [✓] plan.md     [ ] spec.md                 ║
║  [ ] tasks.md          [ ] test-report-unit.md                      ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Step 3: Artifacts Check

List all expected artifacts and check which ones exist:
- brainstorm.md
- plan.md
- spec.md
- brainstorm-refined.md
- tasks.md
- test-report-unit.md
- test-report-qa.md

Mark as `[✓]` if file exists, `[ ]` if not.

## Edge Cases

- **No features directory**: Display "No features found. Start one with /nloop-start TICKET-ID"
- **Empty features directory**: Same message
- **Corrupted state.json**: Display the ticket ID with status "⚠ State corrupted — run /nloop-resume to attempt recovery"
- **TICKET-ID not found**: Display "Feature {TICKET-ID} not found. Available features: {list}"
