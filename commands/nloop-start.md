---
description: "Start a new feature in the NLoop multi-agent pipeline. Orchestrates the full development lifecycle: brainstorm, plan, review, spec, review, tasks, implement, test, PR."
argument-hint: "TICKET-ID [\"Ticket title and description\"]"
---

# NLoop Orchestrator — Start Feature

You are the **NLoop Orchestrator**, the central engine that drives the multi-agent development pipeline. You coordinate specialized agents through a declarative workflow, manage state, and ensure the pipeline progresses correctly.

## Invocation

```
/nloop-start TICKET-ID
/nloop-start TICKET-ID "Optional ticket description"
```

## Step 1: Initialize Feature

1. Parse the TICKET-ID from: $ARGUMENTS
2. Check if `.nloop/features/{TICKET-ID}/` already exists:
   - If yes: ask user if they want to resume (suggest /nloop-resume) or restart
   - If no: proceed with initialization
3. Create the feature directory structure:
   ```
   .nloop/features/{TICKET-ID}/
   ├── state.json
   ├── reviews/
   └── logs/
   ```
4. Read the state template from `.nloop/engine/templates/feature-state.json`
5. Initialize state.json:
   - Replace `{{TICKET_ID}}` with the actual ticket ID
   - Replace `{{TICKET_TITLE}}` with the ticket title (from args or ask user)
   - Replace `{{TIMESTAMP}}` with current ISO 8601 timestamp
   - Set `current_node` to the first node in the workflow
   - Set `status` to `in_progress`
   - Set `trigger` to `manual`
6. If YouTrack MCP is available, fetch ticket details:
   - Call `youtrack_get_ticket` to get title, description, priority, tags
   - Store description in `state.ticket_description`
   - Store URL in `state.ticket_url`
7. Log event: `workflow_started`

## Step 2: Load Workflow

1. Read the workflow YAML from `.nloop/workflows/default.yaml` (or the workflow specified in state)
2. Parse the YAML to understand:
   - `nodes`: map of node_name -> { agent, action, description, produces, consumes, target, max_rounds, parallel }
   - `edges`: list of { from, to, condition }
   - `defaults`: { max_review_rounds, timeout }
3. Validate that the `current_node` from state exists in the workflow

## Step 3: Orchestration Loop

Execute this loop until `current_node` is a terminal state (`done`, `escalate`, `failed`):

### 3.1: Load Current Node
```
node = workflow.nodes[state.current_node]
```

### 3.2: Load Agent Definition
```
Read the file: .nloop/agents/{node.agent}.md
Parse the frontmatter to get: tools, model, mode, max_review_rounds
```

### 3.3: Build Agent Prompt

Construct the prompt for the agent by combining:

```markdown
# Agent: {agent.display_name}
# Action: {node.action}
# Ticket: {state.ticket_id} — {state.ticket_title}
# Feature Directory: .nloop/features/{TICKET_ID}/

## Your Task
You are performing the "{node.action}" action for ticket {state.ticket_id}.
{node.description}

## Ticket Description
{state.ticket_description or "No description provided — explore the codebase and ask the user if needed."}

## Consumed Artifacts
{For each file in node.consumes: read .nloop/features/{TICKET_ID}/{filename} and include its contents}

## Previous Review Feedback (only if this is a revision after rejection)
{If current_node was reached via a "rejected" edge: read the latest review from .nloop/features/{TICKET_ID}/reviews/}

## Output Instructions
- Write your primary output artifact to: .nloop/features/{TICKET_ID}/{node.produces}
- If this is a review action, include your decision as: ### Decision: APPROVED or ### Decision: REJECTED
- If this is a test action, include your result as: ### Result: PASSED or ### Result: FAILED

{Full agent system prompt from the .md file body (everything after the frontmatter)}
```

### 3.4: Spawn Agent

Use the Claude Code Agent tool:
```
Agent(
  prompt: [the constructed prompt],
  model: node.agent.model (from frontmatter),
  mode: node.agent.mode (from frontmatter),
  isolation: "worktree" (ONLY if node.agent == "developer" and node.parallel == true),
  description: "{node.agent}: {node.action} for {state.ticket_id}"
)
```

**Special case — execute-tasks node (parallel dispatch)**:
When `node.parallel == true` and `node.action == "dispatch-tasks"`:
1. Read `.nloop/features/{TICKET_ID}/tasks.md`
2. Identify the next group of runnable tasks (dependencies met)
3. For each task in the group (up to `config.parallel.max_concurrent_agents`):
   - Spawn a developer agent with `isolation: "worktree"`
   - Pass only the relevant task + spec excerpt
4. Wait for all agents to complete
5. Collect results, update tasks.md progress
6. If more groups remain, repeat
7. When all tasks are done, proceed to next edge

### 3.5: Process Agent Output

1. Parse the agent's response for:
   - **Decision** (for review nodes): look for `### Decision: APPROVED` or `### Decision: REJECTED`
   - **Result** (for test nodes): look for `### Result: PASSED` or `### Result: FAILED`
   - **Status** (for other nodes): `COMPLETED` by default if no errors
2. Determine the `condition` from the output:
   - `approved` -> if Decision is APPROVED
   - `rejected` -> if Decision is REJECTED
   - `passed` -> if Result is PASSED
   - `failed` -> if Result is FAILED
   - `null` -> unconditional (no decision/result in output)

### 3.6: Handle Review Rounds

If the current node is a review node (has `target` field):
1. Read the current round count: `state.review_rounds[node.target]`
2. If condition is `rejected`:
   - Increment: `state.review_rounds[node.target] += 1`
   - Check against `node.max_rounds` (or `defaults.max_review_rounds`)
   - If rounds exceeded: override condition to `max_rounds_exceeded`
3. Save the review artifact to `.nloop/features/{TICKET_ID}/reviews/{target}-review-{round}.md`

### 3.7: Resolve Next Edge

1. Find all edges where `edge.from == state.current_node`
2. If condition is not null:
   - Find the edge where `edge.condition == condition`
   - If no matching conditional edge found -> error
3. If condition is null:
   - Find the edge where `edge.condition` is not set (unconditional)
   - If no unconditional edge found -> error
4. Set `state.current_node = edge.to`

### Review Loop Deep Dive

The review loop is the most critical mechanism in NLoop. Here's exactly how it works:

**When a review node (e.g., `review-plan`) rejects:**
1. The orchestrator increments `state.review_rounds.plan` (e.g., from 1 to 2)
2. It checks: `review_rounds.plan >= node.max_rounds` (default 4)?
   - If YES: set condition to `max_rounds_exceeded` -> edge goes to `escalate`
   - If NO: condition stays `rejected` -> edge goes back to `plan` node
3. The review artifact is saved to `reviews/plan-review-{round}.md`
4. When the `plan` node executes again, the orchestrator MUST include in the prompt:
   - The previous review feedback from `reviews/plan-review-{round}.md`
   - A note: "This is revision {round}. Address the following review feedback."
5. The revised artifact overwrites `plan.md`
6. Flow goes back to `review-plan` for another round

**When a review node approves:**
1. The round counter is NOT incremented
2. Condition is `approved` -> edge goes to the next phase
3. The review artifact is saved (for audit trail)

**Escalation:**
1. When `max_rounds_exceeded`, state is updated:
   ```json
   "escalation": {
     "active": true,
     "reason": "Review of plan exceeded 4 rounds without approval",
     "node": "review-plan",
     "at": "{timestamp}"
   }
   ```
2. Status changes to `escalated`
3. Pipeline pauses — user must `/nloop-resume` after resolving

### 3.8: Update State

1. Add history entry:
   ```json
   {
     "node": "{previous_node}",
     "agent": "{node.agent}",
     "action": "{node.action}",
     "status": "{completed|rejected|approved|passed|failed}",
     "round": {round number if review},
     "started_at": "{start_time}",
     "completed_at": "{now}",
     "output_artifact": "{node.produces or null}",
     "decision": "{APPROVED|REJECTED|null}",
     "comments": "{brief summary}"
   }
   ```
2. Update `state.updated_at` to current timestamp
3. Write state.json completely (overwrite)

### 3.9: Log Event

Append to `.nloop/features/{TICKET_ID}/logs/events.jsonl`:
```json
{"ts":"{now}","event":"node_completed","node":"{node_name}","agent":"{agent}","status":"{status}"}
{"ts":"{now}","event":"edge_traversed","from":"{previous_node}","to":"{new_node}","condition":"{condition}"}
```

### 3.10: Display Progress

After each node completion, display:
```
[NLoop] {TICKET_ID} | {previous_node} -> {condition or "->"} -> {new_node} | Review rounds: {rounds if applicable}
```

### 3.11: Continue Loop

Go back to Step 3.1 with the new `current_node`.

## Step 4: Terminal State Handling

### If current_node == "done"
1. Set `state.status = "completed"`
2. Set `state.completed_at` to current timestamp
3. Log event: `workflow_completed`
4. Display:
   ```
   NLoop: Feature {TICKET_ID} completed successfully!
   PR: {state.pr.url}
   Artifacts: .nloop/features/{TICKET_ID}/
   ```

### If current_node == "escalate"
1. Set `state.status = "escalated"`
2. Log event: `workflow_escalated`
3. Display:
   ```
   NLoop: Feature {TICKET_ID} escalated — human intervention needed.
   Reason: {state.escalation.reason}
   Node: {state.escalation.node}
   To resume after resolving: /nloop-resume {TICKET_ID}
   ```

### If current_node == "failed"
1. Set `state.status = "failed"`
2. Log event: `workflow_failed`
3. Display failure details

## Error Handling

- **Agent spawn fails**: Log the error, retry once. If still fails, escalate.
- **Agent produces unexpected output**: Log warning, try to parse. If unparseable, escalate.
- **State file corrupted**: Attempt to reconstruct from history. If impossible, escalate.
- **Workflow edge not found**: Log error with details. This indicates a workflow YAML bug. Escalate.

## Logging System

### Event Log (events.jsonl)

Append one JSON line per event to `.nloop/features/{TICKET_ID}/logs/events.jsonl`.

**Event types and their fields**:

| Event | Required Fields |
|-------|----------------|
| `workflow_started` | ts, event, ticket, workflow, trigger |
| `workflow_resumed` | ts, event, ticket, resumed_from |
| `node_entered` | ts, event, node, agent, action |
| `node_completed` | ts, event, node, agent, status, artifact, duration_s |
| `edge_traversed` | ts, event, from, to, condition |
| `review_decision` | ts, event, node, decision, round, comments |
| `task_dispatched` | ts, event, task_id, task_title, agent, worktree |
| `task_completed` | ts, event, task_id, status, duration_s |
| `escalation` | ts, event, node, reason |
| `pr_created` | ts, event, pr_url, branch |
| `workflow_completed` | ts, event, ticket, duration_total_s |
| `workflow_escalated` | ts, event, ticket, reason, node |
| `workflow_failed` | ts, event, ticket, error |

### Summary Report (summary.md)

After **each phase completion** (not every node, only when transitioning to a new major phase), update `.nloop/features/{TICKET_ID}/logs/summary.md`:

1. Read the summary template from `.nloop/engine/templates/feature-summary.md`
2. Update the Timeline table with the completed phase
3. Update the Current Phase section
4. Check which artifacts exist and update the checklist
5. Update review history and task progress sections
6. Overwrite the summary.md file

## Important Rules

1. **Always save state before spawning the next agent** — this ensures recoverability
2. **Never modify the workflow YAML** — it's configuration, not runtime state
3. **Always log events** — observability is critical for debugging
4. **Respect max_concurrent_agents** — don't spawn more than the configured limit
5. **Pass only relevant context to agents** — don't dump the entire feature directory into every prompt
6. **Update summary.md after each major phase** — keeps the human-readable report current
