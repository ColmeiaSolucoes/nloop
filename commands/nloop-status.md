---
description: "Display the NLoop dashboard showing status of all features in the pipeline."
argument-hint: "[TICKET-ID]"
---

# NLoop Status Dashboard

You render a terminal dashboard showing the status of all features in the NLoop pipeline.

## Invocation

```
/nloop-status              # Overview of all features
/nloop-status TICKET-ID    # Detailed view of a specific feature
```

Arguments: $ARGUMENTS

## Overview Mode (no arguments)

### Step 1: Scan Features

1. List all directories in `.nloop/features/`
2. For each directory, read `state.json`
3. Group features by status: `in_progress`, `escalated`, `pending`, `completed`, `failed`

### Step 2: Render Dashboard

Display the following dashboard:

```
+======================================================================+
|                       NLOOP STATUS DASHBOARD                          |
|                       {current date and time}                         |
+======================================================================+
|                                                                       |
|  ACTIVE ({count})                                                     |
|  -------------                                                        |
|  {TICKET-ID}  {title (truncated to 30 chars)}  {progress_bar} {node} |
|  {TICKET-ID}  {title (truncated to 30 chars)}  {progress_bar} {node} |
|                                                                       |
|  ESCALATED ({count})                                                  |
|  ----------------                                                     |
|  {TICKET-ID}  {title}  ! {escalation.reason} at {escalation.node}    |
|                                                                       |
|  WAITING APPROVAL ({count})                                           |
|  -------------------------                                            |
|  {TICKET-ID}  {title}  [{priority}]                                  |
|                                                                       |
|  COMPLETED (last 5)                                                   |
|  --------------------                                                 |
|  {TICKET-ID}  {title}  OK  PR: {pr.url}                              |
|                                                                       |
|  STATS                                                                |
|  -----                                                                |
|  Total: {n} | Active: {n} | Completed: {n} | Escalated: {n}          |
|                                                                       |
+======================================================================+
```

### Progress Bar Logic

Progress is calculated **dynamically** from the workflow YAML — NOT from a hardcoded list.

1. Read the workflow YAML for the feature (from `state.workflow`)
2. Build the ordered node list by traversing edges from the first node to `done` (following the happy path — approved, passed conditions)
3. Calculate total steps = number of nodes in the happy path
4. Find the index of `state.current_node` in the ordered list
5. Progress = `(current_node_index / total_steps)`

```
Progress bar format: ##########------ (12 chars, filled proportionally)
```

For `execute-tasks` node, show task progress: `Tasks: {completed}/{total}`

For review nodes, show round: `review-plan (2/4)`

**Example node counts per workflow:**
- default: ~17 nodes (brainstorm → post-mortem)
- bugfix: ~12 nodes (brainstorm → post-mortem, no plan/spec)
- hotfix: ~8 nodes (brainstorm → post-mortem, minimal)
- refactor: ~15 nodes (brainstorm → post-mortem, no QA)

## Detail Mode (/nloop-status TICKET-ID)

### Step 1: Read State

Read `.nloop/features/{TICKET-ID}/state.json`

### Step 2: Render Detail View

```
+======================================================================+
|  FEATURE: {TICKET-ID} - {ticket_title}                               |
+======================================================================+
|                                                                       |
|  Status: {status}          Workflow: {workflow}                        |
|  Started: {started_at}     Updated: {updated_at}                      |
|  Current Node: {current_node}                                         |
|  Trigger: {trigger}                                                   |
|                                                                       |
|  REVIEW ROUNDS                                                        |
|  -------------                                                        |
|  Plan: {n}/4    Spec: {n}/4    Code: {n}/4                            |
|                                                                       |
|  TASKS                                                                |
|  -----                                                                |
|  Total: {n}  Completed: {n}  In Progress: {n}  Failed: {n}           |
|                                                                       |
|  PR                                                                   |
|  --                                                                   |
|  URL: {pr.url or "Not created yet"}                                   |
|  Branch: {pr.branch or "N/A"}                                         |
|                                                                       |
|  HISTORY                                                              |
|  -------                                                              |
|  {timestamp}  {node} -> {status} ({agent}: {action})                  |
|  {timestamp}  {node} -> {status} ({agent}: {action})                  |
|  ...                                                                  |
|                                                                       |
|  ARTIFACTS                                                            |
|  ---------                                                            |
|  [x] brainstorm.md     [x] plan.md     [ ] spec.md                   |
|  [ ] tasks.md          [ ] test-report-unit.md                        |
|                                                                       |
+======================================================================+
```

### Step 3: Artifacts Check

List all expected artifacts (based on the workflow being used) and check which ones exist:
- brainstorm.md
- plan.md (not in bugfix/hotfix)
- spec.md (not in bugfix/hotfix)
- brainstorm-refined.md (only in default)
- tasks.md (not in hotfix)
- perf-report.md (only in default/refactor)
- test-report-unit.md
- test-report-qa.md (not in hotfix/refactor)
- docs-update.md
- changelog-entry.md
- help-article.md
- post-mortem.md

Mark as `[x]` if file exists, `[ ]` if not, `-` if not expected for this workflow.

## Edge Cases

- **No features directory**: Display "No features found. Start one with /nloop-start TICKET-ID"
- **Empty features directory**: Same message
- **Corrupted state.json**: Display the ticket ID with status "! State corrupted - run /nloop-resume to attempt recovery"
- **TICKET-ID not found**: Display "Feature {TICKET-ID} not found. Available features: {list}"
