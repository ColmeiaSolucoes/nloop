---
description: "Live progress view for an NLoop feature pipeline. Shows real-time node transitions, agent activity, and elapsed time."
argument-hint: "TICKET-ID [--tail N]"
---

# NLoop Watch — Live Pipeline Progress

Display real-time progress of a running NLoop feature pipeline. Shows which node is currently executing, elapsed time per phase, and a live timeline of events.

## Invocation

```
/nloop-watch TICKET-ID
/nloop-watch TICKET-ID --tail 20
```

Arguments: $ARGUMENTS

## Step 1: Parse Arguments

1. Extract TICKET-ID from arguments
2. Extract `--tail N` (default: 50) — number of recent events to show

## Step 2: Validate Feature

1. Check `.nloop/features/{TICKET_ID}/state.json` exists
   - If not: "Feature {TICKET_ID} not found. Run `/nloop-start {TICKET_ID}` first."
2. Read `state.json` to get current status
3. Read the workflow YAML to understand the full pipeline

## Step 3: Build Progress View

### 3.1: Read State

```json
{
  "ticket_id": "...",
  "status": "in_progress|completed|escalated|failed",
  "workflow": "default",
  "current_node": "code-review",
  "started_at": "...",
  "history": [...]
}
```

### 3.2: Read Event Log

Read `.nloop/features/{TICKET_ID}/logs/events.jsonl`:
- Parse each line as JSON
- Sort by timestamp
- Take the last N events (based on --tail)

### 3.3: Read Workflow Graph

Read `.nloop/workflows/{workflow}.yaml`:
- List all nodes in order
- Mark completed, current, and pending nodes

## Step 4: Display Dashboard

```
🔄 NLoop Watch — {TICKET_ID}: {ticket_title}
══════════════════════════════════════════════════════

  Status:    {status_emoji} {status}
  Workflow:  {workflow_name}
  Started:   {started_at} ({elapsed} ago)
  Updated:   {updated_at} ({time_since} ago)

────────────────────────────────────────────────────
📍 Pipeline Progress
────────────────────────────────────────────────────

  ✅ brainstorm          tech-leader         2m 15s
  ✅ plan                product-planner     5m 42s
  ✅ review-plan         tech-leader         1m 30s    APPROVED (round 1)
  ✅ architecture        architect           8m 12s
  ✅ review-spec         tech-leader         2m 05s    REJECTED (round 1)
  ✅ architecture        architect           4m 33s    (revision 2)
  ✅ review-spec         tech-leader         1m 12s    APPROVED (round 2)
  ✅ brainstorm-refine   tech-leader         1m 45s
  ✅ task-planning       project-manager     3m 20s
  ✅ execute-tasks       project-manager     12m 05s   3 tasks parallel
  🔄 code-review        code-reviewer       --:--     IN PROGRESS
  ⬚  perf-analysis      perf-analyzer       --:--
  ⬚  unit-testing       unit-tester         --:--
  ⬚  qa-testing         qa-tester           --:--
  ⬚  docs-update        docs-writer         --:--
  ⬚  create-pr          tech-leader         --:--
  ⬚  post-mortem        tech-leader         --:--

  Progress: 10/17 nodes (59%)
  ████████████░░░░░░░░░ 59%

────────────────────────────────────────────────────
📊 Stats
────────────────────────────────────────────────────

  Total elapsed:       42m 19s
  Review rounds:       plan 1/4, spec 2/4, code 0/4
  Tasks:               3/3 completed
  Bugs found:          0 (so far)
  Nodes skipped:       0

────────────────────────────────────────────────────
📜 Recent Events (last {N})
────────────────────────────────────────────────────

  {timestamp}  node_completed   architecture    architect       COMPLETED    8m 12s
  {timestamp}  edge_traversed   architecture → review-spec     (unconditional)
  {timestamp}  review_decision  review-spec     tech-leader     REJECTED     round 1
  {timestamp}  edge_traversed   review-spec → architecture     (rejected)
  {timestamp}  node_completed   architecture    architect       COMPLETED    4m 33s
  {timestamp}  edge_traversed   architecture → review-spec     (unconditional)
  {timestamp}  review_decision  review-spec     tech-leader     APPROVED     round 2
  {timestamp}  edge_traversed   review-spec → brainstorm-refine (approved)
  ...

────────────────────────────────────────────────────
🗂️  Artifacts
────────────────────────────────────────────────────

  ✅ brainstorm.md          (exists)
  ✅ plan.md                (exists)
  ✅ spec.md                (exists, revision 2)
  ✅ brainstorm-refined.md  (exists)
  ✅ tasks.md               (exists)
  ⬚  test-report-unit.md   (pending)
  ⬚  test-report-qa.md     (pending)
  ⬚  perf-report.md        (pending)
  ⬚  docs-update.md        (pending)
  ⬚  changelog-entry.md    (pending)
  ⬚  post-mortem.md        (pending)
```

## Step 5: Status-Specific Views

### If status == "completed"

```
✅ Feature {TICKET_ID} completed!

  Total duration:  1h 23m
  PR:              {pr_url}
  Artifacts:       .nloop/features/{TICKET_ID}/

  View post-mortem:  /nloop-metrics {TICKET_ID}
```

### If status == "escalated"

```
⚠️  Feature {TICKET_ID} escalated — human intervention needed

  Escalated at:    {timestamp}
  Node:            {escalation.node}
  Reason:          {escalation.reason}
  Review rounds:   {rounds_used}/{max_rounds}

  Last review feedback:
  {latest review content excerpt}

  To resume:  /nloop-resume {TICKET_ID}
```

### If status == "failed"

```
❌ Feature {TICKET_ID} failed

  Failed at:       {timestamp}
  Node:            {current_node}
  Error:           {error details}

  Check logs:  .nloop/features/{TICKET_ID}/logs/events.jsonl
```

## Step 6: Pipeline Visualization

For the progress section, compute node states:

1. **Completed nodes** (✅): nodes in state.history with status completed/approved/passed
2. **Current node** (🔄): state.current_node (if status is in_progress)
3. **Skipped nodes** (⏭️): nodes in state.skipped_nodes
4. **Pending nodes** (⬚): all remaining nodes in the workflow

For review nodes that were rejected, show the full loop:
```
  ✅ review-spec         tech-leader         2m 05s    REJECTED (round 1)
  ✅ architecture        architect           4m 33s    (revision 2)
  ✅ review-spec         tech-leader         1m 12s    APPROVED (round 2)
```

For parallel execution nodes, show the task breakdown:
```
  ✅ execute-tasks       project-manager     12m 05s   3 tasks parallel
     ├─ Task 1: Add model       developer   4m 12s    ✅
     ├─ Task 2: Add API         developer   6m 45s    ✅
     └─ Task 3: Add UI          developer   8m 05s    ✅
```

## Error Handling

- **Feature not found**: "Feature {TICKET_ID} not found. Available features: {list}"
- **No events yet**: "Feature {TICKET_ID} exists but has no events yet. It may not have started processing."
- **Corrupted state**: "Warning: state.json may be corrupted. Showing data from events.jsonl instead."
