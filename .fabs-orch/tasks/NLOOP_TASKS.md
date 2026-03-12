# NLoop — Multi-Agent Orchestration System — Tasks

## Codinome: NLOOP
## Data: 2026-03-12
## Spec: .fabs-orch/specs/NLOOP_SPEC.md

## Progress: 24/24 tasks completed

---

## EPIC 1: Core Infrastructure (Tasks 1–8)

### Task 1: Project scaffold and directory structure
- **Status:** [x] Completed
- **Description:** Create the full `nloop/` directory structure with all subdirectories (agents, workflows, config, skills, mcp, engine, features). Add a root README.md and .gitignore.
- **Files:**
  - `nloop/` (all subdirectories)
  - `nloop/README.md`
  - `nloop/.gitignore`
- **Acceptance Criteria:**
  - [ ] All directories exist: agents/, workflows/, config/, skills/, engine/, engine/templates/, mcp/youtrack/, features/
  - [ ] .gitignore excludes node_modules, .env, features/*/logs/, dist/

---

### Task 2: Global configuration files
- **Status:** [x] Completed
- **Description:** Create `config/nloop.yaml` (global settings: models, polling, parallel, bitbucket) and `config/triggers.yaml` (trigger rules for ticket auto-start vs approval).
- **Files:**
  - `nloop/config/nloop.yaml`
  - `nloop/config/triggers.yaml`
- **Acceptance Criteria:**
  - [ ] nloop.yaml contains all sections: default_workflow, polling, models, review, parallel, bitbucket, features_dir
  - [ ] triggers.yaml contains sample rules with auto_start, require_approval, and ignore actions
  - [ ] Both files are valid YAML

---

### Task 3: State schema and templates
- **Status:** [x] Completed
- **Description:** Create the JSON schema for feature state files and the initial state template. Also create markdown templates for feature artifacts.
- **Files:**
  - `nloop/engine/state-schema.json`
  - `nloop/engine/templates/feature-state.json`
  - `nloop/engine/templates/feature-plan.md`
  - `nloop/engine/templates/feature-spec.md`
  - `nloop/engine/templates/feature-tasks.md`
- **Acceptance Criteria:**
  - [ ] state-schema.json is valid JSON Schema that validates the state structure from the spec
  - [ ] feature-state.json template has all fields with sensible defaults/placeholders
  - [ ] Markdown templates have consistent structure with placeholder sections

---

### Task 4: Workflow definition — default.yaml
- **Status:** [x] Completed
- **Description:** Create the default workflow YAML with all nodes and edges as specified in the tech spec. Include the full state graph with conditional edges for review loops, escalation, and terminal states.
- **Files:**
  - `nloop/workflows/default.yaml`
- **Acceptance Criteria:**
  - [ ] All 13 nodes defined: brainstorm, plan, review-plan, architecture, review-spec, brainstorm-refinement, task-planning, execute-tasks, code-review, unit-testing, qa-testing, bug-fixing, create-pr
  - [ ] All edges defined with correct conditions (approved, rejected, max_rounds_exceeded, passed, failed)
  - [ ] Special terminal nodes referenced: done, escalate
  - [ ] defaults section with max_review_rounds and timeout
  - [ ] Valid YAML

---

### Task 5: Tech Leader agent definition
- **Status:** [x] Completed
- **Description:** Create the Tech Leader agent .md file with full frontmatter (tools, model, actions, connections), system prompt covering all 5 actions (brainstorm, review, brainstorm-refinement, dispatch-fixes, create-pr), constraints, output format, and few-shot examples for each action.
- **Files:**
  - `nloop/agents/tech-leader.md`
- **Acceptance Criteria:**
  - [ ] Frontmatter with all fields: name, display_name, role, description, tools, model, mode, actions, max_review_rounds, timeout, receives_from, sends_to, produces, consumes
  - [ ] System prompt with context, instructions per action, constraints, output_format
  - [ ] At least 2 examples (review-approve, review-reject)
  - [ ] Review output includes explicit APPROVED/REJECTED decision

---

### Task 6: Developer agent definition
- **Status:** [x] Completed
- **Description:** Create the Developer agent .md file. This agent implements individual tasks in isolated worktrees. Prompt should guide it to read the spec excerpt, implement changes, run basic validation (lint/typecheck if available), and report completion.
- **Files:**
  - `nloop/agents/developer.md`
- **Acceptance Criteria:**
  - [ ] Frontmatter with tools: Read, Write, Edit, Grep, Glob, Bash
  - [ ] Model: sonnet
  - [ ] Prompt covers: reading task context, implementing changes, running validation, reporting results
  - [ ] Example of task implementation with output format
  - [ ] Constraints: minimal changes, follow existing code style, don't modify unrelated files

---

### Task 7: Orchestrator skill — /nloop-start
- **Status:** [x] Completed
- **Description:** Create the main orchestrator skill that drives the entire pipeline. This skill reads the workflow YAML, manages state, builds agent prompts, spawns agents via the Agent tool, processes results, and loops until terminal state. Also handles feature directory creation and state initialization.
- **Files:**
  - `nloop/skills/nloop-start/SKILL.md`
- **Acceptance Criteria:**
  - [ ] Skill frontmatter with name, description, user-invocable: true
  - [ ] Instructions for: parsing workflow YAML, creating feature directory, initializing state, building agent prompts, spawning agents, processing results, updating state, resolving edges, handling review rounds, escalation, terminal states
  - [ ] Clear step-by-step orchestration loop
  - [ ] State update pattern (read → modify → write)
  - [ ] Event logging pattern (append to events.jsonl)
  - [ ] Error handling: what to do if agent fails, if state is corrupted
  - [ ] Resume capability: can pick up from any state.current_node

---

### Task 8: Status skill — /nloop-status
- **Status:** [x] Completed
- **Description:** Create the dashboard skill that scans all feature state files and renders a terminal dashboard showing active features, their current phase, progress, escalations, and completed features.
- **Files:**
  - `nloop/skills/nloop-status/SKILL.md`
- **Acceptance Criteria:**
  - [ ] Scans features/ directory for all state.json files
  - [ ] Groups features by status: active, waiting_approval, escalated, completed
  - [ ] Shows progress bar or fraction for task-based phases
  - [ ] Shows current node and review round for active features
  - [ ] Shows PR URL for completed features
  - [ ] ASCII-art dashboard format as specified in the spec

---

## EPIC 2: Planning Agents (Tasks 9–14)

### Task 9: Product Planner agent definition
- **Status:** [x] Completed
- **Description:** Create the Product Planner agent. This agent takes a brainstorm artifact and ticket description, researches the codebase and optionally the web, and produces a comprehensive plan.md.
- **Files:**
  - `nloop/agents/product-planner.md`
- **Acceptance Criteria:**
  - [ ] Frontmatter with tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch
  - [ ] Model: sonnet
  - [ ] Prompt covers: reading brainstorm artifact, analyzing codebase, creating structured plan
  - [ ] Output follows feature-plan.md template structure
  - [ ] Example of plan output

---

### Task 10: Senior Software Architect agent definition
- **Status:** [x] Completed
- **Description:** Create the Architect agent. Takes plan.md and brainstorm as input, performs deep codebase analysis, produces detailed spec.md with file changes, data models, APIs, code sketches.
- **Files:**
  - `nloop/agents/architect.md`
- **Acceptance Criteria:**
  - [ ] Frontmatter with tools: Read, Write, Edit, Grep, Glob
  - [ ] Model: opus
  - [ ] Prompt covers: deep codebase analysis, architecture decisions, producing spec with exact file paths, code sketches
  - [ ] Output follows feature-spec.md template structure
  - [ ] Example of spec output with file change table and code sketch

---

### Task 11: Project Manager agent definition
- **Status:** [x] Completed
- **Description:** Create the Project Manager agent. Two actions: create-tasks (breaks spec into EPICs/tasks with dependency graph) and dispatch-tasks (identifies runnable tasks and spawns developers).
- **Files:**
  - `nloop/agents/project-manager.md`
- **Acceptance Criteria:**
  - [ ] Frontmatter with tools: Read, Write, Edit, Grep, Glob
  - [ ] Model: sonnet
  - [ ] Two action sections: create-tasks and dispatch-tasks
  - [ ] create-tasks: produces tasks.md with dependency graph, parallel groups, acceptance criteria per task
  - [ ] dispatch-tasks: reads tasks.md, identifies next runnable group, spawns developer agents, updates progress
  - [ ] Example of tasks.md output with dependency annotations
  - [ ] Example of parallel group identification

---

### Task 12: Resume skill — /nloop-resume
- **Status:** [x] Completed
- **Description:** Create the resume skill that picks up a feature from its last saved state and continues the orchestration loop.
- **Files:**
  - `nloop/skills/nloop-resume/SKILL.md`
- **Acceptance Criteria:**
  - [ ] Reads existing state.json for the given TICKET-ID
  - [ ] Validates state integrity (required fields present, current_node exists in workflow)
  - [ ] Logs resume event
  - [ ] Continues orchestration from state.current_node using the same logic as nloop-start
  - [ ] Handles edge cases: escalated features, completed features, corrupted state

---

### Task 13: Review loop mechanism in orchestrator
- **Status:** [x] Completed
- **Description:** Update the nloop-start skill to include detailed review loop logic: tracking review rounds in state, passing previous review feedback to the agent on revision, detecting max_rounds_exceeded, and escalation handling.
- **Files:**
  - `nloop/skills/nloop-start/SKILL.md` (update)
- **Acceptance Criteria:**
  - [ ] Review round counter incremented in state.review_rounds on each rejection
  - [ ] Previous review comments passed as context when agent revises
  - [ ] Max rounds check against node config and global default
  - [ ] Escalation: sets state.escalation, moves to escalate node, notifies human
  - [ ] Clear instructions for orchestrator to parse APPROVED/REJECTED from agent output

---

### Task 14: Brainstorm skill integration
- **Status:** [x] Completed
- **Description:** Define how the brainstorm action in the Tech Leader and the brainstorm-refinement action integrate with the existing brainstorming patterns. The brainstorm action should explore the ticket systematically, and brainstorm-refinement should validate the complete plan+spec before task breakdown.
- **Files:**
  - `nloop/agents/tech-leader.md` (update brainstorm/brainstorm-refinement action sections)
- **Acceptance Criteria:**
  - [ ] brainstorm action: reads ticket description, explores problem space, produces brainstorm.md with key decisions and approaches
  - [ ] brainstorm-refinement action: reads plan.md + spec.md, identifies gaps or conflicts, produces brainstorm-refined.md
  - [ ] Both actions produce structured output artifacts

---

## EPIC 3: Quality Agents (Tasks 15–19)

### Task 15: Code Reviewer agent definition
- **Status:** [x] Completed
- **Description:** Create the Code Reviewer agent. Reviews git diffs, checks for security issues, code quality, adherence to spec, outputs APPROVED/REJECTED with line-specific comments.
- **Files:**
  - `nloop/agents/code-reviewer.md`
- **Acceptance Criteria:**
  - [ ] Frontmatter with tools: Read, Grep, Glob, Bash(git diff, git log, git show)
  - [ ] Model: sonnet
  - [ ] Prompt covers: reviewing diffs, checking against spec, security checks, code quality
  - [ ] Output: APPROVED/REJECTED with specific file:line comments
  - [ ] Example of review output (approve and reject cases)

---

### Task 16: Unit Tester agent definition
- **Status:** [x] Completed
- **Description:** Create the Unit Tester agent. Detects test framework, runs existing tests, writes new tests for uncovered code, outputs PASSED/FAILED with detailed test report.
- **Files:**
  - `nloop/agents/unit-tester.md`
- **Acceptance Criteria:**
  - [ ] Frontmatter with tools: Read, Write, Edit, Grep, Glob, Bash
  - [ ] Model: sonnet
  - [ ] Framework detection table (Jest, Pytest, Go test, etc.)
  - [ ] Prompt covers: running tests, analyzing failures, writing new tests, generating report
  - [ ] Output: PASSED/FAILED + test-report-unit.md
  - [ ] Example of test report output

---

### Task 17: QA Tester agent definition
- **Status:** [x] Completed
- **Description:** Create the QA Tester agent. Uses Chrome MCP for visual/E2E testing and the dogfood skill for systematic exploration. Outputs PASSED/FAILED with screenshots and bug report.
- **Files:**
  - `nloop/agents/qa-tester.md`
- **Acceptance Criteria:**
  - [ ] Frontmatter with tools: Read, Write, Grep, Glob, Bash, mcp__claude-in-chrome__* tools
  - [ ] Skills: dogfood
  - [ ] Model: sonnet
  - [ ] Prompt covers: starting the app, navigating pages, visual verification, systematic bug hunting
  - [ ] Output: PASSED/FAILED + test-report-qa.md with screenshots
  - [ ] Example of QA report output

---

### Task 18: Bug fixing dispatch flow
- **Status:** [x] Completed
- **Description:** Define the bug-fixing workflow within the Tech Leader agent. When tests fail, the Tech Leader reads test reports, creates fix tasks, and dispatches them to developer agents. Then routes back to code-review.
- **Files:**
  - `nloop/agents/tech-leader.md` (update dispatch-fixes action)
- **Acceptance Criteria:**
  - [ ] dispatch-fixes action: reads test-report-unit.md and test-report-qa.md
  - [ ] Creates targeted fix tasks from test failures
  - [ ] Spawns developer agents for fixes
  - [ ] Updates tasks.md with fix tasks and their status
  - [ ] Routes back to code-review after fixes complete

---

### Task 19: PR creation flow
- **Status:** [x] Completed
- **Description:** Define the create-pr action in the Tech Leader agent. Creates a feature branch (if not already on one), commits all changes, pushes to remote, and creates a PR on Bitbucket via API.
- **Files:**
  - `nloop/agents/tech-leader.md` (update create-pr action)
- **Acceptance Criteria:**
  - [ ] create-pr action: creates/checks out feature branch
  - [ ] Commits with meaningful message referencing ticket ID
  - [ ] Pushes to Bitbucket remote
  - [ ] Creates PR via Bitbucket REST API with title, description, reviewers
  - [ ] Updates state.json with PR URL and branch
  - [ ] Includes PR description template with summary, changes, and test results

---

## EPIC 4: External Integrations (Tasks 20–24)

### Task 20: YouTrack MCP server
- **Status:** [x] Completed
- **Description:** Create the YouTrack MCP server in TypeScript using @modelcontextprotocol/sdk. Expose 6 tools: list_tickets, get_ticket, update_status, add_comment, get_comments, update_field. Auth via environment variables.
- **Files:**
  - `nloop/mcp/youtrack/package.json`
  - `nloop/mcp/youtrack/tsconfig.json`
  - `nloop/mcp/youtrack/src/index.ts`
- **Acceptance Criteria:**
  - [ ] Valid package.json with dependencies: @modelcontextprotocol/sdk, zod, typescript
  - [ ] All 6 tools implemented with proper Zod schemas for parameters
  - [ ] Auth via YOUTRACK_TOKEN and YOUTRACK_BASE_URL env vars
  - [ ] Error handling for API failures
  - [ ] Builds successfully with `npm run build`

---

### Task 21: Poll skill — /nloop-poll
- **Status:** [x] Completed
- **Description:** Create the polling skill that queries YouTrack for new tickets, evaluates trigger rules, and either auto-starts or queues for approval. Designed to be called via `/loop 30m /nloop-poll`.
- **Files:**
  - `nloop/skills/nloop-poll/SKILL.md`
- **Acceptance Criteria:**
  - [ ] Calls YouTrack MCP to list new tickets (configurable query from nloop.yaml)
  - [ ] Reads triggers.yaml and evaluates rules top-to-bottom
  - [ ] For auto_start: creates feature directory + starts orchestration
  - [ ] For require_approval: logs to a pending-approval list and notifies
  - [ ] For ignore: skips
  - [ ] Tracks already-processed tickets to avoid duplicates (via state files existence check)

---

### Task 22: Trigger rules engine
- **Status:** [x] Completed
- **Description:** Define in the orchestrator how trigger rules from triggers.yaml are parsed and evaluated. Rules match on tags, priority, and project with first-match-wins logic.
- **Files:**
  - `nloop/skills/nloop-poll/SKILL.md` (update with trigger evaluation logic)
- **Acceptance Criteria:**
  - [ ] Rules evaluated top-to-bottom, first match wins
  - [ ] Match criteria: tags (array contains), priority (array contains), project (array contains), empty match (catch-all)
  - [ ] Actions: auto_start, require_approval, ignore
  - [ ] Clear instructions for how the orchestrator evaluates each rule

---

### Task 23: Structured logging system
- **Status:** [x] Completed
- **Description:** Define the logging conventions used throughout the orchestrator and agents. Each feature has events.jsonl (machine-readable) and summary.md (human-readable progress report updated after each phase).
- **Files:**
  - `nloop/engine/templates/feature-summary.md`
  - `nloop/skills/nloop-start/SKILL.md` (update with logging instructions)
- **Acceptance Criteria:**
  - [ ] events.jsonl format defined with event types: workflow_started, node_entered, node_completed, edge_traversed, review_decision, task_dispatched, task_completed, escalation, pr_created
  - [ ] summary.md template with sections updated after each phase completion
  - [ ] Orchestrator instructions include logging at each step
  - [ ] Events include timestamps, node, agent, action, status, and relevant metadata

---

### Task 24: Dashboard enhancement — /nloop-status
- **Status:** [x] Completed
- **Description:** Enhance the nloop-status skill with complete dashboard rendering: ASCII art, progress bars, color-coded status, and summary statistics. Also add ability to view detailed log for a specific feature.
- **Files:**
  - `nloop/skills/nloop-status/SKILL.md` (update)
- **Acceptance Criteria:**
  - [ ] Dashboard shows: active features, waiting for approval, escalated, completed (last 5)
  - [ ] Progress bars for task execution phases
  - [ ] Review round indicators (e.g., "review-spec 2/4")
  - [ ] `/nloop-status TICKET-ID` shows detailed view: full history, current artifacts, logs
  - [ ] Summary stats: total features processed, avg time per phase, current queue size

---

## Dependency Graph

```
Group 1 (no dependencies — parallel):
  Task 1: Project scaffold
  Task 2: Global config
  Task 3: State schema + templates
  Task 4: Workflow default.yaml

Group 2 (depends on Group 1 — parallel):
  Task 5: Tech Leader agent
  Task 6: Developer agent
  Task 7: Orchestrator skill /nloop-start
  Task 8: Status skill /nloop-status

Group 3 (depends on Group 2 — parallel):
  Task 9: Product Planner agent
  Task 10: Architect agent
  Task 11: Project Manager agent
  Task 12: Resume skill /nloop-resume
  Task 13: Review loop mechanism (updates Task 7)
  Task 14: Brainstorm integration (updates Task 5)

Group 4 (depends on Group 3 — parallel):
  Task 15: Code Reviewer agent
  Task 16: Unit Tester agent
  Task 17: QA Tester agent
  Task 18: Bug fixing flow (updates Task 5)
  Task 19: PR creation flow (updates Task 5)

Group 5 (depends on Group 4 — parallel):
  Task 20: YouTrack MCP server
  Task 21: Poll skill /nloop-poll
  Task 22: Trigger rules engine (updates Task 21)
  Task 23: Logging system (updates Task 7)
  Task 24: Dashboard enhancement (updates Task 8)
```
