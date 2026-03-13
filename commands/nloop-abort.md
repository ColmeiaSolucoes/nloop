---
description: "Abort a running NLoop feature pipeline. Cleans up worktrees, marks state as aborted, and optionally notifies via webhooks."
argument-hint: "TICKET-ID [--cleanup]"
---

# NLoop Abort — Cancel Feature Pipeline

Cancel a running or escalated feature pipeline. This is a safe way to stop a feature that's no longer needed or has gone off track.

## Invocation

```
/nloop-abort TICKET-ID
/nloop-abort TICKET-ID --cleanup
```

Arguments: $ARGUMENTS

## Step 1: Validate Feature

1. Parse TICKET-ID from `$ARGUMENTS`
2. Check if `.nloop/features/{TICKET_ID}/` exists
   - If not: display "Feature {TICKET_ID} not found." and stop
3. Read `.nloop/features/{TICKET_ID}/state.json`
4. If `state.status == "completed"`:
   - Display "Feature {TICKET_ID} is already completed. Nothing to abort."
   - Stop
5. If `state.status == "aborted"`:
   - Display "Feature {TICKET_ID} was already aborted."
   - Stop

## Step 2: Confirm Abort

Display the current state and ask for confirmation:

```
[NLoop] Abort feature {TICKET_ID}?

  Status:       {state.status}
  Current node: {state.current_node}
  Workflow:     {state.workflow}
  Started:      {state.started_at}
  Tasks:        {state.tasks.completed}/{state.tasks.total} completed

  This will:
  - Mark the feature as "aborted"
  - Clean up any active git worktrees (if --cleanup flag is set)
  - Send abort notification (if webhooks configured)

  Type "yes" to confirm:
```

If user doesn't confirm, display "Abort cancelled." and stop.

## Step 3: Cleanup Worktrees

If `--cleanup` flag is present OR if any tasks are in `in_progress` status:

1. Check for active worktrees related to this feature:
   ```bash
   git worktree list | grep "{TICKET_ID}"
   ```
2. For each matching worktree:
   - Remove the worktree:
     ```bash
     git worktree remove {worktree_path} --force
     ```
   - Delete the associated branch:
     ```bash
     git branch -D {branch_name}
     ```
3. Log each cleanup action

If no `--cleanup` flag and no active worktrees, skip this step.

## Step 4: Update State

1. Set `state.status = "aborted"`
2. Set `state.completed_at` to current timestamp
3. Add history entry:
   ```json
   {
     "node": "{state.current_node}",
     "agent": "user",
     "action": "abort",
     "status": "aborted",
     "started_at": "{now}",
     "completed_at": "{now}",
     "comments": "Pipeline aborted by user"
   }
   ```
4. Write state.json

## Step 5: Log Event

Append to `.nloop/features/{TICKET_ID}/logs/events.jsonl`:
```json
{"ts":"{now}","event":"workflow_aborted","ticket":"{TICKET_ID}","node":"{current_node}","reason":"user_abort"}
```

## Step 6: Update YouTrack (if MCP available)

1. Add comment to ticket: `"NLoop pipeline aborted at node '{current_node}' by user."`
2. Do NOT change ticket status — the user may want to restart or handle it manually

## Step 7: Send Notifications

If notifications are configured and `workflow_failed` is in the events list:
- Send notification: "Pipeline for {TICKET_ID} was aborted at node `{current_node}` by user."
- Use the same notification format as `workflow_failed`

## Step 8: Display Summary

```
[NLoop] Feature {TICKET_ID} aborted.

  Aborted at node: {current_node}
  Tasks completed: {completed}/{total}
  Worktrees cleaned: {n}

  To restart this feature:
    /nloop-start {TICKET_ID}

  To view the partial artifacts:
    .nloop/features/{TICKET_ID}/
```

## Error Handling

- **Worktree removal fails**: Log warning, continue with other cleanup. Display manual cleanup instructions at the end.
- **State file locked/corrupted**: Force overwrite with aborted status.
- **Notification fails**: Log warning, don't block.
