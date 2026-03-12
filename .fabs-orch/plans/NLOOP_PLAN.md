# NLoop — Multi-Agent Orchestration System — Plan

## Codinome: NLOOP
## Data: 2026-03-12

## Overview

NLoop is a multi-agent orchestration system built as a Claude Code skill/agent hybrid that automates the full software development lifecycle — from ticket intake (YouTrack) through planning, architecture, implementation, code review, testing, and PR creation (Bitbucket). It runs as a persistent loop in a dedicated Claude Code terminal session, polling for new tickets or responding to manual commands.

The system models a virtual software team with specialized agents (Tech Leader, Product Planner, Architect, Project Manager, Developers, Code Reviewer, Unit Tester, QA Tester), each defined as configurable `.md` files with frontmatter metadata, prompts, and few-shot examples.

## Brainstorming Summary

### Key Decisions
1. **Runtime**: Claude Code hybrid (C+) — skills as entry points, agents as configurable `.md` files, runs in dedicated terminal session
2. **Polling**: Via `/loop` skill for periodic YouTrack checks + manual `/nloop-start TICKET-ID` command
3. **YouTrack Integration**: Custom MCP server exposing tools like `youtrack_list_tickets`, `youtrack_update_status`, etc.
4. **Bitbucket Integration**: API REST for PR creation and notifications
5. **Review Model**: Max 4 revision rounds per agent (configurable), then escalate to human
6. **Parallelism**: Semi-parallel via worktrees — independent tasks run in parallel, dependent tasks run sequentially. Dependency graph defined by Project Manager
7. **Persistence**: Hybrid — `.md` documents (human-readable artifacts) + `.json` metadata (machine state control)
8. **Trigger Rules**: Configurable filters per YouTrack project/tag/priority (auto-start vs approval required)
9. **PR Workflow**: Auto-create PR on Bitbucket + notify human. No auto-merge
10. **Observability**: Structured JSON logs + phase summaries in `.md` + terminal dashboard (`/nloop-status`)
11. **Testing**: Two separate agents — Unit Tester (code tests) and QA Tester (visual/E2E via Chrome MCP + dogfood skill)
12. **Agent Definition Format**: `.md` files with YAML frontmatter (metadata + config) + system prompt + few-shot examples
13. **Build Strategy**: Incremental by layers (4 phases)

### Agents Defined
| # | Agent | Role |
|---|-------|------|
| 1 | Tech Leader | Central orchestrator — distributes, reviews, escalates |
| 2 | Product Planner | Decomposes ideas, researches, creates detailed plans |
| 3 | Senior Software Architect | Technical specification and architecture design |
| 4 | Project Manager | EPICs, Tasks, dependency graph, scheduling, progress tracking |
| 5 | Developer | Implements tasks (multiple instances via worktrees) |
| 6 | Code Reviewer | Reviews code quality, security, standards compliance |
| 7 | Unit Tester | Runs/writes unit and integration tests |
| 8 | QA Tester | Visual/E2E testing via Chrome MCP + dogfood skill |

## Current State Analysis

### Existing Patterns in Claude Code Ecosystem
- **Agent definition pattern**: `.claude/agents/{name}.md` with frontmatter (`name`, `description`, `tools`, `model`, `permissionMode`, `skills`, `hooks`). Agents have isolated context and restricted tools.
- **Skill definition pattern**: `.claude/skills/{name}/SKILL.md` with frontmatter. Skills share conversation context and have full tool access by default.
- **Orchestration pattern**: The `nvibe` skill demonstrates sequential phase orchestration (Brainstorm → Plan → Tech → Task Manager) with artifact generation in `.fabs-orch/`.
- **Agent spawning**: Claude Code's `Agent` tool supports `subagent_type`, `isolation: "worktree"`, `mode`, `model` parameters for spawning subagents.
- **Periodic execution**: The `/loop` skill supports running commands on intervals (e.g., `/loop 30m /nloop-poll`).

### What Doesn't Exist Yet
- No state machine / workflow engine for multi-agent pipelines
- No persistent state management between agent handoffs
- No YouTrack or Bitbucket MCP integrations
- No dashboard/status visualization system
- No configurable review loop mechanism

## Competitor Research

### CrewAI
- **Architecture**: Agents defined in YAML/Python with `role`, `goal`, `backstory`, `tools`. Tasks assigned to agents with `expected_output`.
- **Workflow**: Sequential or hierarchical process. A "manager" agent can delegate to crew members (similar to our Tech Leader).
- **Review loops**: Built-in `max_iter` parameter for task retry. Human-in-the-loop via callbacks.
- **State**: Shared memory via crew-level context. Task outputs flow as inputs to next tasks.
- **Strength**: Simple YAML-based agent definition, easy to configure.
- **Weakness**: Limited graph-based workflows, no native git/PR integration.
- **Relevant pattern**: The `hierarchical` process type where a manager delegates is very close to our Tech Leader model.

### MetaGPT
- **Architecture**: Simulates a software company with roles (ProductManager, Architect, ProjectManager, Engineer, QA). Each role has an SOP (Standard Operating Procedure) defining its workflow.
- **Workflow**: Message-passing between roles via a shared message pool. Roles subscribe to message types they care about.
- **Review loops**: Built into the SOP — Engineer writes code, QA reviews, bugs go back to Engineer.
- **State**: Shared workspace with documents (PRD, Design Doc, Task List, Code). Very similar to our `.md` artifact approach.
- **Strength**: Most similar to our concept. Role-based specialization with document artifacts.
- **Weakness**: Monolithic Python codebase, hard to customize individual roles without code changes.
- **Relevant pattern**: The document-driven workflow (PRD → Design → Tasks → Code → Review) maps directly to our flow. Their use of "actions" per role (WritePRD, WriteDesign, WriteCode, RunTests) is a good pattern.

### ChatDev
- **Architecture**: "Chat Chain" pattern — pairs of agents have structured conversations (CEO↔CPO, CTO↔Programmer, Reviewer↔Programmer, Tester↔Programmer).
- **Workflow**: Sequential chat phases with defined roles per phase.
- **Review loops**: Explicit code review phase where Reviewer and Programmer iterate.
- **State**: Shared "software" artifact that evolves through phases.
- **Strength**: The paired conversation model produces high-quality outputs through dialogue.
- **Weakness**: Rigid phase structure, hard to add custom roles or parallel execution.
- **Relevant pattern**: The idea of structured dialogue between pairs (Tech Leader ↔ Product Planner) rather than monologue could improve our review quality.

### LangGraph
- **Architecture**: State machine with nodes (agents/functions) and edges (transitions). Conditional edges enable dynamic routing.
- **Workflow**: Graph-based — nodes process state, edges define flow. Supports cycles (loops) natively.
- **Review loops**: Conditional edges that route back to previous nodes based on state (e.g., `if review == "rejected" → go back to developer`).
- **State**: Explicit `State` object passed between nodes. Reducers handle state updates.
- **Strength**: Most flexible for complex workflows with loops and conditionals. Native cycle support.
- **Weakness**: Requires coding the graph in Python, no declarative config format.
- **Relevant pattern**: The state graph with conditional edges is the best model for our workflow. We should adopt this pattern but define it declaratively in a `workflow.yaml` or `workflow.md`.

### AutoGen (Microsoft)
- **Architecture**: Agents in a `GroupChat` with a manager that selects the next speaker. Or two-agent conversations with `initiate_chat`.
- **Workflow**: Conversation-based — agents take turns in a group chat, or sequential two-agent chats.
- **Review loops**: `max_round` parameter + termination conditions. Agents can request re-work.
- **State**: Conversation history is the shared state. Also supports external memory.
- **Strength**: Flexible conversation patterns, good for iterative refinement.
- **Weakness**: State management relies heavily on conversation context (token-expensive).
- **Relevant pattern**: The `GroupChat` with a manager selecting the next speaker is similar to our Tech Leader routing model.

### Claude Agent SDK
- **Architecture**: Lightweight SDK for building agents on top of Claude API. Supports tool use, multi-turn conversations, and agent delegation.
- **Workflow**: Agent loop pattern — agent receives input, reasons, uses tools, returns output. Can delegate to sub-agents.
- **State**: Conversation messages + tool results. External state via tool calls.
- **Strength**: Native Claude integration, simple API surface.
- **Weakness**: Low-level — no built-in orchestration, workflow, or state management.
- **Relevant pattern**: The agent loop (think → act → observe → repeat) is the foundational pattern. Claude Code's Agent tool already implements this.

### Key Takeaways for NLoop
1. **From MetaGPT**: Document-driven workflow with role-based SOPs. Each agent produces/consumes specific document types.
2. **From LangGraph**: State graph with conditional edges for routing (review loops, escalation). Define workflow declaratively.
3. **From CrewAI**: YAML-based agent definition with clear role/goal/tools. Hierarchical manager pattern.
4. **From ChatDev**: Paired dialogue for review phases (richer feedback than monologue).
5. **From AutoGen**: Configurable max rounds with termination conditions.
6. **Our unique advantage**: Native Claude Code integration with worktrees, MCPs, skills, and the Agent tool — no external framework needed.

## Desired End State

A fully operational system where:

1. **Ticket arrives** (via polling or manual command) → automatically enters the pipeline
2. **Each phase produces documented artifacts** in a feature-specific directory
3. **Agents collaborate through review loops** with configurable max rounds and human escalation
4. **Multiple tasks execute in parallel** via git worktrees when dependency graph allows
5. **Code is reviewed, tested (unit + visual), and a PR is created** on Bitbucket automatically
6. **Full observability** — logs, phase summaries, and a terminal dashboard show real-time progress
7. **Everything is configurable** — agent behavior, workflow, review rounds, trigger rules — by editing `.md` and `.yaml` files
8. **Adding/removing/modifying agents** requires only editing their definition file

## What We're NOT Doing

1. **Custom UI/Web Dashboard** — Terminal-only for now. No web interface.
2. **Auto-merge PRs** — Always creates PR, never merges automatically.
3. **Multi-repo support** — Single repository at a time.
4. **Custom LLM providers** — Claude only, via Claude Code's native Agent tool.
5. **Database for state** — File-based persistence only (`.md` + `.json`).
6. **Deployment/CD automation** — Stops at PR creation.
7. **Building a standalone daemon** — Runs within Claude Code session only.

## Implementation Approach

### Architecture: Declarative Orchestration Engine

```
.nloop/
├── agents/                          # Agent definitions (configurable)
│   ├── tech-leader.md
│   ├── product-planner.md
│   ├── architect.md
│   ├── project-manager.md
│   ├── developer.md
│   ├── code-reviewer.md
│   ├── unit-tester.md
│   └── qa-tester.md
│
├── workflows/                       # Workflow definitions (declarative)
│   └── default.yaml                 # State graph: nodes, edges, conditions
│
├── config/                          # System configuration
│   ├── nloop.yaml                   # Global settings (polling interval, defaults)
│   └── triggers.yaml                # YouTrack filter rules for auto-start vs approval
│
├── skills/                          # Claude Code skills (entry points)
│   ├── nloop-start/SKILL.md         # Manual: /nloop-start TICKET-ID
│   ├── nloop-poll/SKILL.md          # Polling: checks YouTrack for new tickets
│   └── nloop-status/SKILL.md        # Dashboard: /nloop-status
│
├── mcp/                             # MCP servers
│   └── youtrack/                    # YouTrack MCP server
│       ├── index.ts
│       └── package.json
│
├── engine/                          # Orchestration engine (core logic)
│   ├── orchestrator.md              # Main orchestrator agent — reads workflow, manages state, dispatches agents
│   ├── state-schema.json            # JSON Schema for feature state files
│   └── templates/                   # Templates for feature artifacts
│       ├── feature-plan.md
│       ├── feature-spec.md
│       ├── feature-tasks.md
│       └── feature-state.json
│
└── features/                        # Active feature workspaces (runtime)
    └── {TICKET-ID}/
        ├── state.json               # Machine state (phase, round, timestamps)
        ├── plan.md                   # Product Planner output
        ├── spec.md                   # Architect output
        ├── tasks.md                  # Project Manager output
        ├── reviews/                  # Review artifacts per phase
        │   ├── plan-review-1.md
        │   └── spec-review-2.md
        └── logs/
            ├── events.jsonl          # Structured event log
            └── summary.md            # Human-readable progress summary
```

### Core Concept: The Orchestrator Agent

The heart of NLoop is an **orchestrator agent** (defined in `engine/orchestrator.md`) that:

1. Reads the workflow definition (`workflows/default.yaml`)
2. Reads the current feature state (`features/{TICKET-ID}/state.json`)
3. Determines the next step (which agent to invoke, with what input)
4. Spawns the appropriate agent via Claude Code's Agent tool
5. Captures the output, updates state, and decides the next transition
6. Handles review loops (approve/reject/escalate logic)
7. Repeats until the workflow reaches a terminal state

### Workflow Definition (Declarative State Graph)

Inspired by LangGraph, the workflow is defined as a YAML state graph:

```yaml
# workflows/default.yaml
name: default
description: Standard development workflow

nodes:
  brainstorm:
    agent: tech-leader
    action: brainstorm
    description: Triage and brainstorm the ticket

  plan:
    agent: product-planner
    action: create-plan
    description: Create detailed product plan

  review-plan:
    agent: tech-leader
    action: review
    target: plan
    max_rounds: 4

  architecture:
    agent: architect
    action: create-spec
    description: Create technical specification

  review-spec:
    agent: tech-leader
    action: review
    target: spec
    max_rounds: 4

  brainstorm-refinement:
    agent: tech-leader
    action: brainstorm-refinement
    description: Final brainstorm with complete spec

  task-planning:
    agent: project-manager
    action: create-tasks
    description: Break into EPICs and tasks with dependency graph

  execute-tasks:
    agent: project-manager
    action: dispatch-tasks
    description: Dispatch tasks to developers (parallel via worktrees)

  code-review:
    agent: code-reviewer
    action: review-code
    max_rounds: 4

  unit-testing:
    agent: unit-tester
    action: run-tests

  qa-testing:
    agent: qa-tester
    action: visual-test

  bug-fixing:
    agent: tech-leader
    action: dispatch-fixes
    description: Distribute bug fixes from test results

  create-pr:
    agent: tech-leader
    action: create-pr
    description: Create PR on Bitbucket

edges:
  - from: brainstorm
    to: plan

  - from: plan
    to: review-plan

  - from: review-plan
    to: plan
    condition: rejected

  - from: review-plan
    to: escalate
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
    to: done
```

### Feature State (Machine Control)

```json
{
  "ticket_id": "PROJ-123",
  "ticket_title": "Add dark mode support",
  "feature_dir": "features/PROJ-123",
  "workflow": "default",
  "current_node": "review-plan",
  "status": "in_progress",
  "started_at": "2026-03-12T10:00:00Z",
  "updated_at": "2026-03-12T11:30:00Z",
  "review_rounds": {
    "plan": 2,
    "spec": 0
  },
  "tasks": {
    "total": 0,
    "completed": 0,
    "in_progress": 0,
    "failed": 0
  },
  "history": [
    { "node": "brainstorm", "status": "completed", "at": "2026-03-12T10:15:00Z" },
    { "node": "plan", "status": "completed", "at": "2026-03-12T10:45:00Z" },
    { "node": "review-plan", "status": "rejected", "round": 1, "at": "2026-03-12T11:00:00Z" },
    { "node": "plan", "status": "completed", "at": "2026-03-12T11:20:00Z" },
    { "node": "review-plan", "status": "in_progress", "round": 2, "at": "2026-03-12T11:30:00Z" }
  ]
}
```

## Phases

### Phase 1: Core Infrastructure
- Orchestration engine (orchestrator agent + state management + workflow parser)
- Feature directory structure and state schema
- Tech Leader agent (brainstorm + review actions)
- Developer agent (implement tasks)
- Basic skills: `/nloop-start`, `/nloop-status`
- **Deliverable**: Can manually start a ticket, Tech Leader brainstorms, dispatches to Developer, tracks state

### Phase 2: Planning Agents
- Product Planner agent
- Senior Software Architect agent
- Project Manager agent (task decomposition + dependency graph)
- Brainstorm skill integration
- Review loop mechanism with max rounds + escalation
- **Deliverable**: Full planning pipeline (brainstorm → plan → review → spec → review → tasks)

### Phase 3: Quality Agents
- Code Reviewer agent
- Unit Tester agent
- QA Tester agent (Chrome MCP + dogfood skill)
- Bug fixing dispatch loop
- PR creation on Bitbucket (API integration)
- **Deliverable**: Full quality pipeline (code review → unit tests → visual tests → PR)

### Phase 4: External Integrations
- YouTrack MCP server (polling, status updates, comments)
- `/nloop-poll` skill + `/loop` integration
- Trigger rules configuration (`triggers.yaml`)
- Terminal dashboard (`/nloop-status` with kanban-style view)
- Structured logging system (`events.jsonl` + `summary.md`)
- **Deliverable**: Fully autonomous system with polling, dashboard, and complete observability

## Risks & Open Questions

### Risks
1. **Token consumption**: Each agent call consumes tokens. A full pipeline for one ticket could use substantial tokens. Need to monitor and potentially use cheaper models (Haiku/Sonnet) for simpler agents.
2. **Rate limits**: Claude Code API rate limits may bottleneck parallel execution. Need to handle gracefully with retries and queuing.
3. **State corruption**: If Claude Code crashes mid-pipeline, state files could be inconsistent. Need atomic state updates and recovery logic.
4. **Worktree conflicts**: Parallel developers working on the same files via worktrees will create merge conflicts. The dependency graph must account for file-level conflicts.
5. **Context window limits**: Complex features with large codebases may exceed agent context windows. Need to be strategic about what context each agent receives.

### Open Questions
1. **Model selection per agent**: Should simpler agents (Developer for small tasks) use Haiku while complex agents (Architect) use Opus? Configurable per agent.
2. **YouTrack MCP scope**: What YouTrack operations do we need beyond list/read/update? Comments? Attachments? Time tracking?
3. **Bitbucket auth**: Token-based or OAuth? Need to define the auth flow for the Bitbucket API.
4. **Recovery strategy**: If the terminal session dies, how do we resume? The state files support this, but the orchestrator needs explicit resume logic.
5. **Multi-feature concurrency**: Can we run multiple features simultaneously? The architecture supports it, but Claude Code may struggle with too many parallel agents.

## References

### Codebase
- Agent definition pattern: `~/.claude/skills/create-agents/SKILL.md`
- Skill definition pattern: `~/.claude/skills/create-skill/SKILL.md`
- Orchestration pattern: `~/.claude/skills/nvibe/SKILL.md`

### Competitor Frameworks
- CrewAI: https://docs.crewai.com
- MetaGPT: https://github.com/geekan/MetaGPT
- ChatDev: https://github.com/OpenBMB/ChatDev
- LangGraph: https://langchain-ai.github.io/langgraph/
- AutoGen: https://microsoft.github.io/autogen/
- Claude Agent SDK: https://docs.anthropic.com/en/docs/agents
