# NLoop — Multi-Agent Orchestration System — Technical Specification

## Codinome: NLOOP
## Data: 2026-03-12
## Plan: .fabs-orch/plans/NLOOP_PLAN.md

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CLAUDE CODE TERMINAL                         │
│                     (Dedicated Session + /loop)                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐     ┌──────────────────────────────────────┐     │
│  │  SKILLS       │     │  ORCHESTRATOR ENGINE                  │     │
│  │  (Entry Points)│────▶│                                      │     │
│  │               │     │  1. Parse workflow YAML               │     │
│  │ /nloop-start  │     │  2. Read/Write state.json             │     │
│  │ /nloop-poll   │     │  3. Resolve next node                 │     │
│  │ /nloop-status │     │  4. Load agent definition (.md)       │     │
│  │ /nloop-resume │     │  5. Spawn Agent via Agent tool        │     │
│  └──────────────┘     │  6. Capture output → update state     │     │
│                        │  7. Evaluate edges → transition        │     │
│                        │  8. Loop until terminal state          │     │
│                        └───────┬──────────────────────────────┘     │
│                                │                                     │
│                    ┌───────────┼───────────────────┐                │
│                    ▼           ▼                   ▼                │
│              ┌──────────┐ ┌──────────┐     ┌──────────┐           │
│              │ Agent 1  │ │ Agent 2  │ ... │ Agent N  │           │
│              │ (fork)   │ │ (fork)   │     │(worktree)│           │
│              └────┬─────┘ └────┬─────┘     └────┬─────┘           │
│                   │            │                 │                  │
│              ┌────▼────────────▼─────────────────▼────┐           │
│              │         FEATURE WORKSPACE               │           │
│              │         features/{TICKET-ID}/            │           │
│              │  ┌─────────┐ ┌────────┐ ┌──────────┐  │           │
│              │  │state.json│ │ *.md   │ │logs/     │  │           │
│              │  └─────────┘ └────────┘ └──────────┘  │           │
│              └─────────────────────────────────────────┘           │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────┐     │
│  │  MCP SERVERS                                              │     │
│  │  ┌────────────┐  ┌─────────────────┐  ┌───────────────┐ │     │
│  │  │  YouTrack   │  │ Chrome DevTools │  │  (future MCPs)│ │     │
│  │  │  MCP        │  │ MCP (existing)  │  │               │ │     │
│  │  └────────────┘  └─────────────────┘  └───────────────┘ │     │
│  └──────────────────────────────────────────────────────────┘     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

1. **No custom runtime** — Everything runs within Claude Code using native Agent tool, skills, and MCPs. No external process manager.
2. **File-based state machine** — The orchestrator is a skill/agent that reads YAML workflow + JSON state and spawns subagents. No database, no message queue.
3. **Agents are prompts, not code** — Each agent is a `.md` file with instructions. The orchestrator reads it and passes it as the prompt to the Agent tool.
4. **Workflow is data, not code** — The state graph is a YAML file parsed by the orchestrator. Changing the workflow means editing YAML, not code.

---

## Data Models

### 1. Agent Definition Schema (`agents/*.md`)

```yaml
---
# Identity
name: tech-leader                    # Required: lowercase + hyphens
display_name: Tech Leader            # Required: human-readable name
role: orchestrator                   # Required: orchestrator | planner | architect | manager | developer | reviewer | tester
description: >                       # Required: what this agent does
  Central orchestrator responsible for triaging tickets,
  distributing work, reviewing outputs, and escalating to humans.

# Claude Code Agent Config
tools:                               # Required: restricted tool list
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - Bash
model: opus                          # Optional: haiku | sonnet | opus | inherit
mode: default                        # Optional: default | acceptEdits | bypassPermissions

# NLoop-specific Config
actions:                             # Required: what actions this agent can perform
  - brainstorm
  - review
  - brainstorm-refinement
  - dispatch-fixes
  - create-pr
max_review_rounds: 4                 # Optional: default 4
timeout: 30m                         # Optional: max execution time per action

# Workflow Connections
receives_from:                       # Informational: which agents send work here
  - product-planner
  - architect
  - project-manager
  - code-reviewer
  - unit-tester
  - qa-tester
sends_to:                            # Informational: which agents receive work from here
  - product-planner
  - architect
  - project-manager
  - developer

# Artifacts
produces:                            # What files/artifacts this agent creates
  - reviews/*.md
  - brainstorm.md
consumes:                            # What files/artifacts this agent reads
  - plan.md
  - spec.md
  - tasks.md
  - test-report.md
---

# System Prompt

You are the **Tech Leader** of a software development team...

<context>
...
</context>

<instructions>
...
</instructions>

<constraints>
...
</constraints>

<output_format>
...
</output_format>

<examples>
<example>
<action>review</action>
<input>
## Plan: Add dark mode support
...
</input>
<output>
## Review: Plan — Add dark mode support

### Decision: REJECTED

### Issues Found
1. **Missing accessibility consideration** — Dark mode needs to maintain WCAG AA contrast ratios...
2. **No migration path** — Existing users' preferences need to be handled...

### Required Changes
- Add accessibility section with contrast ratio requirements
- Define migration strategy for existing users
- Specify default theme selection logic
</output>
</example>

<example>
<action>review</action>
<input>
## Spec: Add dark mode support (v2, addressing review feedback)
...
</input>
<output>
## Review: Spec — Add dark mode support

### Decision: APPROVED

### Notes
- Accessibility section is comprehensive
- Migration strategy is well-defined
- Ready to proceed to task planning
</output>
</example>
</examples>
```

### 2. Workflow Definition Schema (`workflows/*.yaml`)

```yaml
# workflows/default.yaml
name: default
version: 1
description: Standard development workflow for feature tickets

# Global defaults (can be overridden per node)
defaults:
  max_review_rounds: 4
  timeout: 30m

# Nodes define what happens at each step
nodes:
  brainstorm:
    agent: tech-leader             # Which agent .md file to load
    action: brainstorm             # Which action the agent should perform
    description: Triage and brainstorm the ticket
    produces: brainstorm.md        # Artifact produced

  plan:
    agent: product-planner
    action: create-plan
    description: Create detailed product plan
    produces: plan.md
    consumes:                      # What to feed this agent
      - brainstorm.md

  review-plan:
    agent: tech-leader
    action: review
    target: plan.md                # What artifact to review
    max_rounds: 4                  # Override default

  architecture:
    agent: architect
    action: create-spec
    description: Create technical specification
    produces: spec.md
    consumes:
      - plan.md
      - brainstorm.md

  review-spec:
    agent: tech-leader
    action: review
    target: spec.md
    max_rounds: 4

  brainstorm-refinement:
    agent: tech-leader
    action: brainstorm-refinement
    description: Final brainstorm with complete spec
    produces: brainstorm-refined.md
    consumes:
      - plan.md
      - spec.md

  task-planning:
    agent: project-manager
    action: create-tasks
    description: Break into EPICs and tasks with dependency graph
    produces: tasks.md
    consumes:
      - plan.md
      - spec.md
      - brainstorm-refined.md

  execute-tasks:
    agent: project-manager
    action: dispatch-tasks
    description: Dispatch tasks to developer agents
    parallel: true                 # Enable parallel execution via worktrees
    consumes:
      - tasks.md
      - spec.md

  code-review:
    agent: code-reviewer
    action: review-code
    max_rounds: 4

  unit-testing:
    agent: unit-tester
    action: run-tests
    produces: test-report-unit.md

  qa-testing:
    agent: qa-tester
    action: visual-test
    produces: test-report-qa.md

  bug-fixing:
    agent: tech-leader
    action: dispatch-fixes
    description: Distribute bug fixes from test results
    consumes:
      - test-report-unit.md
      - test-report-qa.md

  create-pr:
    agent: tech-leader
    action: create-pr
    description: Create PR on Bitbucket

# Edges define transitions between nodes
# Unconditional edges: just from → to
# Conditional edges: from → to with condition
edges:
  - from: brainstorm
    to: plan

  - from: plan
    to: review-plan

  - from: review-plan
    to: plan
    condition: rejected

  - from: review-plan
    to: escalate            # Special built-in node
    condition: max_rounds_exceeded

  - from: review-plan
    to: architecture
    condition: approved

  - from: architecture
    to: review-spec

  - from: review-spec
    to: architecture
    condition: rejected

  - from: review-spec
    to: escalate
    condition: max_rounds_exceeded

  - from: review-spec
    to: brainstorm-refinement
    condition: approved

  - from: brainstorm-refinement
    to: task-planning

  - from: task-planning
    to: execute-tasks

  - from: execute-tasks
    to: code-review

  - from: code-review
    to: execute-tasks
    condition: rejected

  - from: code-review
    to: unit-testing
    condition: approved

  - from: unit-testing
    to: qa-testing
    condition: passed

  - from: unit-testing
    to: bug-fixing
    condition: failed

  - from: qa-testing
    to: create-pr
    condition: passed

  - from: qa-testing
    to: bug-fixing
    condition: failed

  - from: bug-fixing
    to: code-review

  - from: create-pr
    to: done                # Special built-in terminal node

# Special built-in nodes (no agent needed):
# - "done": terminal success state
# - "escalate": pauses and notifies human
# - "failed": terminal failure state
```

### 3. Feature State Schema (`features/{TICKET-ID}/state.json`)

```json
{
  "$schema": "engine/state-schema.json",
  "ticket_id": "PROJ-123",
  "ticket_title": "Add dark mode support",
  "ticket_url": "https://youtrack.example.com/issue/PROJ-123",
  "feature_dir": "features/PROJ-123",
  "workflow": "default",
  "current_node": "review-plan",
  "status": "in_progress",
  "trigger": "manual",
  "started_at": "2026-03-12T10:00:00Z",
  "updated_at": "2026-03-12T11:30:00Z",
  "completed_at": null,
  "review_rounds": {
    "plan": 2,
    "spec": 0,
    "code": 0
  },
  "tasks": {
    "total": 0,
    "completed": 0,
    "in_progress": 0,
    "failed": 0,
    "items": []
  },
  "pr": {
    "url": null,
    "branch": null,
    "status": null
  },
  "escalation": {
    "active": false,
    "reason": null,
    "node": null,
    "at": null
  },
  "history": [
    {
      "node": "brainstorm",
      "agent": "tech-leader",
      "action": "brainstorm",
      "status": "completed",
      "started_at": "2026-03-12T10:00:00Z",
      "completed_at": "2026-03-12T10:15:00Z",
      "output_artifact": "brainstorm.md"
    }
  ]
}
```

### 4. Global Config (`config/nloop.yaml`)

```yaml
# config/nloop.yaml
version: 1

# Default workflow to use for new features
default_workflow: default

# Polling settings
polling:
  enabled: true
  interval: 30m              # Used with /loop skill

# Model defaults per agent role
models:
  orchestrator: opus         # Tech Leader needs best reasoning
  planner: sonnet            # Product Planner — balanced
  architect: opus            # Architect needs deep technical reasoning
  manager: sonnet            # Project Manager — balanced
  developer: sonnet          # Developer — balanced speed/quality
  reviewer: sonnet           # Code Reviewer — balanced
  tester: sonnet             # Testers — balanced

# Review defaults
review:
  max_rounds: 4              # Default max review rounds
  escalation_action: pause   # pause | notify | skip

# Parallel execution
parallel:
  max_concurrent_agents: 3   # Max worktrees at once

# Bitbucket
bitbucket:
  base_url: ""               # e.g., https://bitbucket.org
  project: ""                # e.g., MYTEAM
  repo: ""                   # e.g., my-app
  default_reviewers: []      # Bitbucket usernames
  branch_prefix: "feature/"  # Branch naming: feature/PROJ-123

# Feature directory
features_dir: features       # Relative to nloop root
```

### 5. Trigger Rules (`config/triggers.yaml`)

```yaml
# config/triggers.yaml
version: 1

# Rules are evaluated top-to-bottom, first match wins
rules:
  - name: auto-start-tagged
    description: Auto-start tickets tagged with 'nloop-auto'
    match:
      tags: [nloop-auto]
    action: auto_start

  - name: critical-needs-approval
    description: Critical tickets need human approval
    match:
      priority: [Critical, Urgent]
    action: require_approval

  - name: project-specific
    description: Auto-start all tickets from FRONTEND project
    match:
      project: [FRONTEND]
    action: auto_start

  - name: default
    description: Everything else needs approval
    match: {}
    action: require_approval

# Actions:
# - auto_start: immediately enter the workflow
# - require_approval: notify human and wait
# - ignore: skip the ticket
```

### 6. Event Log Entry (`features/{TICKET-ID}/logs/events.jsonl`)

```json
{"ts":"2026-03-12T10:00:00Z","event":"workflow_started","ticket":"PROJ-123","workflow":"default"}
{"ts":"2026-03-12T10:00:01Z","event":"node_entered","node":"brainstorm","agent":"tech-leader","action":"brainstorm"}
{"ts":"2026-03-12T10:15:00Z","event":"node_completed","node":"brainstorm","agent":"tech-leader","status":"completed","artifact":"brainstorm.md"}
{"ts":"2026-03-12T10:15:01Z","event":"edge_traversed","from":"brainstorm","to":"plan","condition":null}
{"ts":"2026-03-12T10:15:02Z","event":"node_entered","node":"plan","agent":"product-planner","action":"create-plan"}
{"ts":"2026-03-12T11:00:00Z","event":"review_decision","node":"review-plan","decision":"rejected","round":1,"comments":"Missing accessibility section"}
{"ts":"2026-03-12T11:00:01Z","event":"edge_traversed","from":"review-plan","to":"plan","condition":"rejected"}
```

---

## API / Interfaces

### Orchestrator Agent Interface

The orchestrator is the central coordination point. It's implemented as a Claude Code skill that reads configs and dispatches agents.

**Input** (received via skill invocation):
```
Command: start | resume | status | poll
Ticket ID: PROJ-123 (for start/resume)
```

**Core Loop (pseudocode)**:
```
function orchestrate(ticket_id, command):
  // 1. Load or create state
  state = load_state(ticket_id) or create_state(ticket_id)
  workflow = parse_yaml("workflows/" + state.workflow + ".yaml")

  // 2. Main loop
  while state.current_node not in ["done", "escalate", "failed"]:
    node = workflow.nodes[state.current_node]
    agent_def = read_file("agents/" + node.agent + ".md")

    // 3. Build agent prompt with context
    prompt = build_prompt(agent_def, node, state)

    // 4. Spawn agent
    if node.parallel and node.action == "dispatch-tasks":
      results = spawn_parallel_agents(state.tasks, agent_def)
    else:
      result = spawn_agent(prompt, agent_def.tools, agent_def.model)

    // 5. Process result and update state
    update_state(state, node, result)
    log_event(state, node, result)

    // 6. Determine next node via edges
    next_node = resolve_edges(workflow.edges, state.current_node, result.condition)

    // 7. Handle review round limits
    if is_review_node(node) and result.condition == "rejected":
      rounds = state.review_rounds[node.target]
      if rounds >= node.max_rounds:
        next_node = "escalate"
        state.escalation = { active: true, reason: "max_rounds", node: state.current_node }

    state.current_node = next_node
    save_state(state)

  // 8. Terminal handling
  if state.current_node == "done":
    notify_completion(state)
  elif state.current_node == "escalate":
    notify_human(state)
```

### Agent Prompt Building

Each agent receives a structured prompt built by the orchestrator:

```markdown
# Agent: {agent.display_name}
# Action: {node.action}
# Ticket: {state.ticket_id} — {state.ticket_title}

## Your Task
{action-specific instructions from the agent .md file}

## Context — Feature Artifacts
{Contents of consumed artifacts: plan.md, spec.md, etc.}

## Previous Review Feedback (if revision)
{Contents of the last review that rejected this artifact}

## Instructions
{Agent system prompt from the .md file}

## Output Requirements
- Write your output to: features/{TICKET-ID}/{artifact_name}
- Your decision (if review): APPROVED | REJECTED
- If REJECTED, list specific required changes
```

### Skill Interfaces

#### `/nloop-start TICKET-ID`
```
1. Fetch ticket details from YouTrack (if MCP available) or accept manual description
2. Create feature directory: features/{TICKET-ID}/
3. Initialize state.json from template
4. Start orchestration loop
```

#### `/nloop-resume TICKET-ID`
```
1. Read existing state.json from features/{TICKET-ID}/
2. Validate state integrity
3. Resume orchestration from state.current_node
```

#### `/nloop-poll`
```
1. Call YouTrack MCP: youtrack_list_tickets(filter=configured_query)
2. For each new ticket:
   a. Evaluate trigger rules
   b. If auto_start: create feature + start orchestration
   c. If require_approval: log and notify
3. Check existing in-progress features for any that need resuming
```

#### `/nloop-status`
```
1. Scan features/ directory for all state.json files
2. Build dashboard:

╔══════════════════════════════════════════════════════════════════╗
║                     NLOOP STATUS DASHBOARD                       ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  ACTIVE FEATURES                                                 ║
║  ───────────────                                                 ║
║  PROJ-123  Dark Mode Support     ██████████░░  review-spec (2/4) ║
║  PROJ-456  API Rate Limiting     ████░░░░░░░░  execute-tasks 3/8 ║
║  PROJ-789  Email Templates       ██████████████ qa-testing       ║
║                                                                  ║
║  WAITING FOR APPROVAL                                            ║
║  ────────────────────                                            ║
║  PROJ-999  Database Migration    [Critical] Needs human approval ║
║                                                                  ║
║  ESCALATED                                                       ║
║  ─────────                                                       ║
║  PROJ-321  Auth Refactor         review-plan exceeded 4 rounds   ║
║                                                                  ║
║  COMPLETED (last 5)                                              ║
║  ──────────────────                                              ║
║  PROJ-100  User Avatars          ✓ PR: https://bb.org/pr/42     ║
║  PROJ-101  Search Filters        ✓ PR: https://bb.org/pr/41     ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## File Changes Required

### New Files

| File | Purpose |
|------|---------|
| `nloop/engine/orchestrator.md` | Main orchestrator — skill that drives the entire pipeline |
| `nloop/engine/state-schema.json` | JSON Schema for state.json validation |
| `nloop/engine/templates/feature-state.json` | Template for new feature state files |
| `nloop/workflows/default.yaml` | Default workflow definition (state graph) |
| `nloop/config/nloop.yaml` | Global configuration |
| `nloop/config/triggers.yaml` | Ticket trigger rules |
| `nloop/agents/tech-leader.md` | Tech Leader agent definition |
| `nloop/agents/product-planner.md` | Product Planner agent definition |
| `nloop/agents/architect.md` | Senior Software Architect agent definition |
| `nloop/agents/project-manager.md` | Project Manager agent definition |
| `nloop/agents/developer.md` | Developer agent definition |
| `nloop/agents/code-reviewer.md` | Code Reviewer agent definition |
| `nloop/agents/unit-tester.md` | Unit Tester agent definition |
| `nloop/agents/qa-tester.md` | QA Tester agent definition |
| `nloop/skills/nloop-start/SKILL.md` | Skill: manually start a ticket |
| `nloop/skills/nloop-resume/SKILL.md` | Skill: resume a paused/crashed feature |
| `nloop/skills/nloop-poll/SKILL.md` | Skill: poll YouTrack for new tickets |
| `nloop/skills/nloop-status/SKILL.md` | Skill: terminal dashboard |
| `nloop/mcp/youtrack/index.ts` | YouTrack MCP server (TypeScript) |
| `nloop/mcp/youtrack/package.json` | YouTrack MCP dependencies |
| `nloop/mcp/youtrack/tsconfig.json` | TypeScript config |

### Modified Files
None — this is a greenfield project.

---

## Implementation Details

### Component 1: Orchestrator Engine (`engine/orchestrator.md`)

The orchestrator is a **Claude Code skill** that contains the logic to drive the state machine. It's the most critical piece — it must be deterministic and robust.

**File**: `nloop/skills/nloop-start/SKILL.md`
**How it works**: The skill reads the workflow YAML, reads/creates state JSON, and uses the Agent tool to spawn specialized agents in a loop.

**Key implementation detail**: The orchestrator itself runs as a skill (shared context), but each specialized agent it spawns runs via the Agent tool (isolated context). This gives us:
- Orchestrator has full visibility of all state and artifacts
- Individual agents are sandboxed with restricted tools
- Agents can't interfere with each other's state

**Prompt construction strategy**:
```markdown
## For the orchestrator skill (nloop-start):

1. Read workflow YAML → parse into nodes/edges structure
2. Read or create state.json
3. Determine current node
4. Read the agent .md file for that node
5. Read all consumed artifacts for that node
6. Build a compound prompt:
   - Agent system prompt (from .md)
   - Action-specific instructions
   - Consumed artifacts as context
   - Output format requirements
7. Spawn via Agent tool:
   - prompt: the compound prompt
   - tools: from agent frontmatter
   - model: from agent frontmatter or config default
   - isolation: "worktree" (only for developer agents)
8. Parse agent output for:
   - Decision (APPROVED/REJECTED/PASSED/FAILED) — for review/test nodes
   - Artifacts produced (files written)
9. Update state.json
10. Log event
11. Resolve next edge
12. Loop
```

### Component 2: Agent Definitions (`agents/*.md`)

Each agent follows a consistent structure but has role-specific content.

**Tech Leader** (`agents/tech-leader.md`):
- **Tools**: `Read, Write, Edit, Grep, Glob, Agent, Bash`
- **Actions**: brainstorm, review, brainstorm-refinement, dispatch-fixes, create-pr
- **Model**: opus (needs best reasoning for review decisions)
- **Key behavior**:
  - On `review`: reads target artifact + any previous review feedback, outputs APPROVED/REJECTED with detailed comments
  - On `brainstorm`: reads ticket description, uses brainstorming skill pattern to explore the problem
  - On `dispatch-fixes`: reads test reports, creates fix tasks, spawns developer agents
  - On `create-pr`: creates branch, commits, pushes, creates PR via Bitbucket API

**Product Planner** (`agents/product-planner.md`):
- **Tools**: `Read, Write, Edit, Grep, Glob, WebSearch, WebFetch`
- **Actions**: create-plan
- **Model**: sonnet
- **Key behavior**: Reads brainstorm artifact, researches the codebase, optionally searches web for best practices, produces a comprehensive plan.md

**Architect** (`agents/architect.md`):
- **Tools**: `Read, Write, Edit, Grep, Glob`
- **Actions**: create-spec
- **Model**: opus
- **Key behavior**: Reads plan.md, deeply analyzes codebase (file structure, existing patterns, APIs), produces detailed spec.md with exact file changes, code sketches, and data models.

**Project Manager** (`agents/project-manager.md`):
- **Tools**: `Read, Write, Edit, Grep, Glob`
- **Actions**: create-tasks, dispatch-tasks
- **Model**: sonnet
- **Key behavior**:
  - On `create-tasks`: reads spec.md, breaks into EPICs/tasks with dependency graph, estimates parallel groups
  - On `dispatch-tasks`: reads tasks.md, identifies next runnable tasks (dependencies met), spawns developer agents (parallel via worktrees for independent tasks)

**Developer** (`agents/developer.md`):
- **Tools**: `Read, Write, Edit, Grep, Glob, Bash`
- **Actions**: implement-task
- **Model**: sonnet
- **Isolation**: worktree (each developer gets its own git worktree)
- **Key behavior**: Receives a single task with context (spec excerpt, files to modify), implements it, runs basic validation (lint, type check).

**Code Reviewer** (`agents/code-reviewer.md`):
- **Tools**: `Read, Grep, Glob, Bash(git diff, git log, git show)`
- **Actions**: review-code
- **Model**: sonnet
- **Key behavior**: Reviews git diff of changes, checks for security issues, code quality, adherence to spec, outputs APPROVED/REJECTED with line-specific comments.

**Unit Tester** (`agents/unit-tester.md`):
- **Tools**: `Read, Write, Edit, Grep, Glob, Bash`
- **Actions**: run-tests
- **Model**: sonnet
- **Key behavior**: Detects test framework, runs existing tests, writes new tests for uncovered code, outputs PASSED/FAILED with test report.

**QA Tester** (`agents/qa-tester.md`):
- **Tools**: `Read, Write, Grep, Glob, Bash, mcp__claude-in-chrome__*`
- **Skills**: `dogfood`
- **Actions**: visual-test
- **Model**: sonnet
- **Key behavior**: Starts the app (if web), uses Chrome MCP to navigate and verify visual/functional behavior, uses dogfood skill for systematic exploration, outputs PASSED/FAILED with screenshots and bug report.

### Component 3: Workflow Parser

The orchestrator needs to parse `workflows/default.yaml` and navigate the state graph. This is done purely in the orchestrator's prompt — no code needed. The orchestrator reads the YAML and follows instructions to:

1. Find the current node in `nodes`
2. After node execution, find all edges where `from` matches current node
3. If edge has `condition`, check if it matches the agent's output decision
4. If edge has no condition (unconditional), take it
5. Special handling for `escalate`, `done`, `failed` terminal nodes

**Edge resolution logic** (in orchestrator prompt):
```
Given current_node and agent_result.decision:

1. Find all edges where edge.from == current_node
2. Filter edges:
   - If agent_result.decision exists:
     - If any conditional edge matches → take it
     - If no conditional edge matches → take unconditional edge (if exists)
   - If no decision (unconditional node):
     - Take the single unconditional edge
3. If no edge found → error: workflow is broken
```

### Component 4: State Management

**Atomic state updates**: The orchestrator must update state.json after every significant action. The update pattern:

```
1. Read state.json
2. Modify in memory
3. Write state.json completely (overwrite)
4. Log event to events.jsonl (append)
```

**Recovery**: If Claude Code crashes:
- state.json reflects the last completed transition
- On `/nloop-resume`, orchestrator reads state.json and continues from current_node
- If current_node was mid-execution (node entered but not completed), the orchestrator re-executes that node (idempotent — artifacts are overwritten)

### Component 5: Parallel Task Execution

When the Project Manager dispatches tasks:

```
1. PM reads tasks.md, identifies dependency groups:
   Group 1 (no dependencies): [Task 1, Task 2, Task 3]  → parallel
   Group 2 (depends on Group 1): [Task 4, Task 5]       → parallel after Group 1
   Group 3 (depends on Task 4): [Task 6]                → sequential after Task 4

2. For each group:
   a. Spawn developer agents in parallel using Agent tool with isolation: "worktree"
   b. Each agent works in its own worktree branch
   c. Wait for all agents in group to complete
   d. Merge worktree branches back to feature branch
   e. Resolve any merge conflicts (escalate if needed)
   f. Update tasks.md progress
   g. Move to next group

3. After all groups complete → move to code-review
```

**Max concurrent agents**: Controlled by `config.parallel.max_concurrent_agents`. If a group has more tasks than the limit, they're batched.

### Component 6: YouTrack MCP Server (`mcp/youtrack/`)

A TypeScript MCP server using the `@modelcontextprotocol/sdk` package.

**Tools exposed**:

| Tool | Description | Parameters |
|------|-------------|------------|
| `youtrack_list_tickets` | List tickets matching a query | `query: string, project?: string, limit?: number` |
| `youtrack_get_ticket` | Get ticket details | `ticket_id: string` |
| `youtrack_update_status` | Update ticket status | `ticket_id: string, status: string` |
| `youtrack_add_comment` | Add comment to ticket | `ticket_id: string, comment: string` |
| `youtrack_get_comments` | Get ticket comments | `ticket_id: string` |
| `youtrack_update_field` | Update a custom field | `ticket_id: string, field: string, value: string` |

**Auth**: Token-based via environment variable `YOUTRACK_TOKEN` and `YOUTRACK_BASE_URL`.

**Implementation sketch**:
```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new McpServer({
  name: "youtrack",
  version: "1.0.0",
});

server.tool("youtrack_list_tickets",
  { query: z.string(), project: z.string().optional(), limit: z.number().default(20) },
  async ({ query, project, limit }) => {
    const url = `${BASE_URL}/api/issues?query=${encodeURIComponent(query)}${project ? `&project=${project}` : ''}&$top=${limit}`;
    const response = await fetch(url, { headers: { Authorization: `Bearer ${TOKEN}`, Accept: "application/json" } });
    const issues = await response.json();
    return { content: [{ type: "text", text: JSON.stringify(issues, null, 2) }] };
  }
);

// ... more tools

const transport = new StdioServerTransport();
await server.connect(transport);
```

### Component 7: Bitbucket Integration

Handled directly by the Tech Leader agent via `Bash` tool with `curl` or a small helper script.

**PR creation flow**:
```bash
# 1. Create branch
git checkout -b feature/PROJ-123

# 2. Commit changes (already done by developers)
# 3. Push to remote
git push -u origin feature/PROJ-123

# 4. Create PR via Bitbucket API
curl -X POST \
  "https://api.bitbucket.org/2.0/repositories/{workspace}/{repo}/pullrequests" \
  -H "Authorization: Bearer ${BITBUCKET_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "PROJ-123: Add dark mode support",
    "description": "## Summary\n...\n## Test Results\n...",
    "source": { "branch": { "name": "feature/PROJ-123" } },
    "destination": { "branch": { "name": "main" } },
    "reviewers": [{ "uuid": "{reviewer-uuid}" }]
  }'
```

**Auth**: Token via environment variable `BITBUCKET_TOKEN`.

---

## Dependencies

### NPM Packages (YouTrack MCP)
| Package | Purpose |
|---------|---------|
| `@modelcontextprotocol/sdk` | MCP server framework |
| `zod` | Schema validation for tool parameters |
| `typescript` | TypeScript compiler |

### Environment Variables Required
| Variable | Purpose |
|----------|---------|
| `YOUTRACK_TOKEN` | YouTrack API bearer token |
| `YOUTRACK_BASE_URL` | YouTrack instance URL (e.g., `https://myteam.youtrack.cloud`) |
| `BITBUCKET_TOKEN` | Bitbucket API token for PR creation |
| `BITBUCKET_WORKSPACE` | Bitbucket workspace slug |
| `BITBUCKET_REPO` | Bitbucket repository slug |

### Claude Code Configuration
The YouTrack MCP needs to be registered in Claude Code's MCP settings:
```json
{
  "mcpServers": {
    "youtrack": {
      "command": "node",
      "args": ["nloop/mcp/youtrack/dist/index.js"],
      "env": {
        "YOUTRACK_TOKEN": "...",
        "YOUTRACK_BASE_URL": "..."
      }
    }
  }
}
```

---

## Testing Strategy

### Unit Tests
- **Workflow YAML parsing**: Validate that the orchestrator correctly reads nodes, edges, and conditions from various workflow configs
- **State transitions**: Test edge resolution logic with mock states (approved → next, rejected → back, max_rounds → escalate)
- **Trigger rules**: Test that trigger matching works correctly (tag match, priority match, project match, default)
- **State recovery**: Test that resume correctly picks up from last saved state

### Integration Tests
- **Single agent round-trip**: Start → brainstorm → complete. Verify state.json and artifact are created correctly
- **Review loop**: Start → plan → review (reject) → plan (revised) → review (approve) → next. Verify round counter and state transitions
- **Escalation**: Start → plan → review (reject x4) → escalate. Verify escalation state
- **Parallel execution**: Dispatch 3 independent tasks → verify all complete and merge back

### Manual Testing
1. Run `/nloop-start TEST-001` with a sample ticket description
2. Observe the orchestrator moving through phases
3. Verify each artifact is produced correctly
4. Test review rejection and revision cycle
5. Test escalation after max rounds
6. Test `/nloop-status` dashboard rendering
7. Test `/nloop-resume` after manually stopping mid-pipeline

---

## Migration / Rollback
Not applicable — greenfield project. No existing data to migrate.

**Feature flags**: Not needed. The system is self-contained and doesn't modify any existing functionality.

**Rollback**: Simply stop using the skills. All NLoop files live in `nloop/` directory — delete to fully remove.

---

## Performance Considerations

1. **Token usage per pipeline run**: A full ticket pipeline (brainstorm → plan → review → spec → review → tasks → implement → review → test → PR) could consume 200k-500k+ tokens depending on codebase size and revision rounds. Mitigation:
   - Use Haiku for simple tasks where possible
   - Keep agent prompts focused and concise
   - Only pass relevant artifact excerpts, not full files

2. **Parallel agent limit**: Claude Code may struggle with more than 3-4 concurrent agents. The `max_concurrent_agents` config defaults to 3.

3. **Worktree overhead**: Each worktree creates a full copy of the working directory. For large repos, this uses significant disk space. Clean up worktrees immediately after merge.

4. **Polling interval**: 30-minute default balances responsiveness vs. API usage. Configurable in `nloop.yaml`.

---

## Security Considerations

1. **API tokens**: YouTrack and Bitbucket tokens must be stored as environment variables, never in config files. The `.gitignore` must exclude any `.env` files.

2. **Agent tool restrictions**: Each agent has minimal tool access. Developers can't use WebSearch. Reviewers can't edit files. This follows the principle of least privilege.

3. **Code execution**: Developer and Tester agents can run `Bash` commands. The orchestrator should not pass untrusted ticket content directly as shell commands. Ticket data is always passed as file content, never interpolated into commands.

4. **Worktree isolation**: Parallel developers work in isolated worktrees, preventing one agent from corrupting another's work.

5. **State file integrity**: state.json is always completely overwritten (not patched), reducing risk of corruption from partial writes.
