---
description: "Resume a paused, escalated, or crashed NLoop feature pipeline from its last saved state."
argument-hint: "TICKET-ID"
---

# NLoop Orchestrator — Resume Feature

Resume a feature pipeline from its last saved state. Use this after:
- Claude Code session crashed or was closed
- A feature was escalated and the human has resolved the issue
- A feature was manually paused

## Invocation

```
/nloop-resume TICKET-ID
```

Arguments: $ARGUMENTS

## Step 1: Validate State

1. Check that `.nloop/features/{TICKET-ID}/` exists
   - If not: display error "Feature {TICKET-ID} not found. Use /nloop-start to create."
2. Read `.nloop/features/{TICKET-ID}/state.json`
3. Validate state integrity:
   - Required fields present: `ticket_id`, `current_node`, `status`, `workflow`
   - `current_node` exists in the workflow YAML
   - `status` is not `completed` (if completed, inform user it's already done)
4. If state is corrupted:
   - Try to reconstruct from `history` array (last entry's next logical node)
   - If impossible, inform user and suggest manual intervention

## Step 2: Handle Escalated Features

If `state.status == "escalated"`:
1. Display the escalation reason and context:
   ```
   Feature {TICKET_ID} was escalated at node "{escalation.node}".
   Reason: {escalation.reason}
   ```
2. Ask the user what to do:
   - **Retry the current node** — re-execute the node that was escalated
   - **Skip to next node** — manually move past the escalation point
   - **Provide feedback** — add guidance that will be passed to the agent on retry
3. Update state based on user choice:
   - Clear `escalation.active = false`
   - Set `status = "in_progress"`
   - If skipping: advance `current_node` to the next logical node

## Step 3: Resume Orchestration

1. Log event: `workflow_resumed` with `resumed_from: {current_node}`
2. Update `state.updated_at` to current timestamp
3. **Continue the orchestration loop** using the exact same logic as `/nloop-start` Step 3.
   - Read the workflow YAML
   - Load the current node
   - Load the agent definition
   - Build the prompt (include any artifacts already produced)
   - Spawn the agent
   - Process output, update state, resolve edges
   - Loop until terminal state

## Step 4: Terminal State Handling

Same as `/nloop-start` Step 4:
- `done` -> mark completed, display PR URL
- `escalate` -> mark escalated, display reason
- `failed` -> mark failed, display details

## Edge Cases

- **Node was mid-execution when crashed**: The state reflects the last completed transition. The current_node will be the node that was in progress. It will be re-executed (this is safe because artifacts are overwritten, making execution idempotent).
- **Multiple resume attempts**: Safe — state is always saved before advancing, so resuming from the same point is idempotent.
- **Feature already completed**: Inform user. Suggest starting a new feature if they want to redo it.
