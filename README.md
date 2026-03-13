# NLoop — Multi-Agent Orchestration for Claude Code

A multi-agent orchestration system that automates the full software development lifecycle — from ticket intake (YouTrack) or feature description through planning, architecture, implementation, code review, performance analysis, testing, documentation, and PR creation (GitHub/Bitbucket).

NLoop models a virtual software team with 10 specialized agents that communicate through a declarative YAML state graph workflow with review loops, parallel execution via git worktrees, smart skip conditions, webhook notifications, and automatic post-mortem metrics.

## Installation

### From Claude Code Marketplace (recommended)

```bash
# 1. Add the NLoop marketplace
claude plugin marketplace add ColmeiaSolucoes/nloop

# 2. Install the plugin
claude plugin install nloop
```

Then, in your project directory, open Claude Code and run:

```
/nloop-init
```

This creates the `.nloop/` directory in your project with agents, config, workflows, and engine templates.

### From Source

```bash
git clone https://github.com/ColmeiaSolucoes/nloop.git /tmp/nloop
cd ~/IdeaProjects/your-project
claude plugin marketplace add /tmp/nloop
claude plugin install nloop
```

Then run `/nloop-init` in Claude Code.

## Quick Start

```bash
# Start a feature from a ticket
/nloop-start TICKET-ID

# Start with a description
/nloop-start PROJ-42 "Add dark mode support"

# Watch live progress
/nloop-watch PROJ-42

# Resume a paused/crashed feature
/nloop-resume TICKET-ID

# Check status dashboard
/nloop-status

# Detailed view of a feature
/nloop-status TICKET-ID

# View metrics and trends
/nloop-metrics

# Weekly analytics report
/nloop-report --period week

# Simulate before running
/nloop-dryrun PROJ-42 --tags backend-only

# Configure polling, git, notifications interactively
/nloop-config polling

# Poll YouTrack for new tickets
/nloop-poll

# Auto-poll every 30 minutes
/loop 30m /nloop-poll
```

## How It Works

### The Agent Loop

NLoop follows a **state graph orchestration** pattern. A central orchestrator reads a YAML workflow definition and executes it node by node. Each node spawns a specialized AI agent that performs one task, produces an artifact, and returns control to the orchestrator. The orchestrator evaluates the result, resolves the next edge in the graph, and continues.

```
┌─────────────────────────────────────────────────────────────────┐
│                     ORCHESTRATOR (nloop-start)                  │
│                                                                 │
│  1. Read workflow YAML (state graph)                            │
│  2. Load current node                                           │
│  3. Check skip conditions → skip if matched                     │
│  4. Read agent definition (.md file)                            │
│  5. Build prompt with consumed artifacts                        │
│  6. Spawn agent (Claude Code Agent tool)                        │
│  7. Parse output: APPROVED/REJECTED/PASSED/FAILED               │
│  8. Resolve next edge based on condition                        │
│  9. Update state.json + log event                               │
│ 10. Send notification (if configured)                           │
│ 11. Go to step 2 (loop until terminal state)                    │
└─────────────────────────────────────────────────────────────────┘
```

Agents **never talk to each other directly**. They communicate through **artifacts** — markdown files stored in the feature directory (`features/{TICKET_ID}/`). Each agent reads artifacts from previous agents and produces new ones.

### Full Pipeline (default workflow)

```
                    ┌──────────────┐
                    │  BRAINSTORM  │ tech-leader
                    │              │ → brainstorm.md
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │     PLAN     │ product-planner
                    │              │ → plan.md
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐     rejected (max 4 rounds)
                    │  REVIEW PLAN │ tech-leader ──────────────┐
                    │              │                            │
                    └──────┬───────┘                            │
                           │ approved          ┌───────────────┘
                           │                   │ (revise plan.md)
                    ┌──────▼───────┐           │
                    │ ARCHITECTURE │ architect  │
                    │              │ → spec.md  │
                    └──────┬───────┘           │
                           │                   │
                    ┌──────▼───────┐     rejected (max 4 rounds)
                    │  REVIEW SPEC │ tech-leader ──────────────┐
                    │              │                            │
                    └──────┬───────┘                            │
                           │ approved          ┌───────────────┘
                           │                   │ (revise spec.md)
                    ┌──────▼───────┐
                    │  REFINEMENT  │ tech-leader
                    │              │ → brainstorm-refined.md
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ TASK PLANNING│ project-manager
                    │              │ → tasks.md
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │EXECUTE TASKS │ project-manager
                    │  [PARALLEL]  │ spawns N developer agents
                    │              │ (isolated git worktrees)
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐     rejected
                    │ CODE REVIEW  │ code-reviewer ────────────┐
                    │              │                            │
                    └──────┬───────┘                            │
                           │ approved          ┌───────────────┘
                           │                   │ (re-execute tasks)
                    ┌──────▼───────┐
                    │PERF ANALYSIS │ perf-analyzer
                    │              │ → perf-report.md
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ UNIT TESTING │ unit-tester
                    │              │ → test-report-unit.md
                    └──────┬───────┘
                           │ passed                    failed
                    ┌──────▼───────┐            ┌──────▼───────┐
                    │  QA TESTING  │ qa-tester   │  BUG FIXING  │
                    │              │             │              │→ back to
                    └──────┬───────┘             └──────────────┘  code-review
                           │ passed
                    ┌──────▼───────┐
                    │  DOCS UPDATE │ docs-writer
                    │              │ → changelog-entry.md
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  CREATE PR   │ tech-leader
                    │              │ → GitHub/Bitbucket PR
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  POST-MORTEM │ tech-leader
                    │              │ → post-mortem.md + metrics
                    └──────┬───────┘
                           │
                        ✅ DONE (+ notify)
```

### Workflow Variants

NLoop selects the workflow automatically based on ticket tags. Each variant removes unnecessary phases:

**Bugfix** — no planning, no architecture, no perf analysis:
```
BRAINSTORM → TASK PLANNING → EXECUTE → CODE REVIEW → UNIT TEST → QA → DOCS → PR → POST-MORTEM
```

**Hotfix** — minimal path, 1 review round max:
```
BRAINSTORM → EXECUTE → CODE REVIEW → UNIT TEST → DOCS → PR → POST-MORTEM
```

**Refactor** — full planning, perf analysis, but no QA:
```
BRAINSTORM → PLAN → REVIEW → ARCHITECTURE → REVIEW → TASK PLANNING → EXECUTE → CODE REVIEW → PERF → UNIT TEST → DOCS → PR → POST-MORTEM
```

### Agent Communication via Artifacts

Agents never share memory or context. They communicate exclusively through files:

```
brainstorm.md ──→ product-planner reads it → plan.md
plan.md       ──→ architect reads it       → spec.md
spec.md       ──→ project-manager reads it → tasks.md
tasks.md      ──→ developers read them     → code changes
code changes  ──→ code-reviewer reads them → approval/rejection
test results  ──→ tech-leader reads them   → bug fix tasks
all artifacts ──→ docs-writer reads them   → changelog + docs
all artifacts ──→ tech-leader reads them   → post-mortem.md
```

Each agent receives **only the artifacts it needs** (defined in `consumes` in the workflow YAML), keeping context focused and token-efficient.

### The 10 Agents

| Agent | Role | Model | Key Actions |
|-------|------|-------|-------------|
| **Tech Leader** | Central orchestrator, quality gatekeeper | opus | brainstorm, review, dispatch-fixes, create-pr, post-mortem |
| **Product Planner** | Decomposes ideas into actionable plans | sonnet | create-plan |
| **Architect** | Designs technical specifications | opus | create-spec |
| **Project Manager** | Breaks specs into EPICs/tasks, dispatches work | sonnet | create-tasks, dispatch-tasks |
| **Developer** | Implements individual tasks in isolated worktrees | sonnet | implement-task |
| **Code Reviewer** | Reviews code quality, security, patterns | sonnet | review-code |
| **Perf Analyzer** | Detects performance regressions and anti-patterns | sonnet | analyze-perf |
| **Unit Tester** | Runs/writes unit and integration tests | sonnet | run-tests |
| **QA Tester** | Visual/E2E testing via Chrome browser automation | sonnet | visual-test |
| **Docs Writer** | Generates changelog, updates project docs | sonnet | update-docs |

Each agent is a `.md` file in `.nloop/agents/` with:
- **Frontmatter**: model, tools, actions, timeout, skip conditions
- **Body**: system prompt with instructions, constraints, output format, and examples

Agents are fully customizable — edit the `.md` file to change behavior, model, or output format.

### Workflow Selection by Ticket Type

NLoop automatically selects the right workflow based on ticket tags:

| Workflow | When | What it skips |
|----------|------|---------------|
| **default** | Features, new functionality | Nothing — full pipeline |
| **bugfix** | Tags: `bugfix`, `bug` | Plan, Architecture, Spec review, Perf analysis |
| **hotfix** | Tags: `hotfix`, `critical-fix` | Plan, Spec, Task planning, QA, Perf analysis |
| **refactor** | Tags: `refactor`, `tech-debt` | QA visual testing, Brainstorm refinement |

Configure mapping in `.nloop/config/nloop.yaml`:

```yaml
workflow_mapping:
  - match:
      tags: [hotfix, critical-fix]
    workflow: hotfix
  - match:
      tags: [bugfix, bug]
    workflow: bugfix
  - match:
      tags: [refactor, tech-debt]
    workflow: refactor
```

### Skip Conditions

Nodes can be automatically skipped based on ticket context:

```yaml
# In workflow YAML
qa-testing:
  agent: qa-tester
  action: visual-test
  skip_if:
    - tag: backend-only    # Skip if ticket tagged backend-only
    - tag: no-ui           # Skip if ticket tagged no-ui
    - no_ui_changes: true  # Skip if no frontend files changed
```

When a node is skipped, NLoop logs it and moves to the next step automatically.

### Review Loops

The Tech Leader reviews plans and specs with up to 4 rounds of feedback. If an agent's output is rejected, it goes back for revision with specific feedback. After max rounds, the pipeline escalates to a human.

### Parallel Execution

The Project Manager breaks specs into task groups with dependency graphs. Independent tasks run in parallel using git worktrees — each developer agent works in its own isolated copy of the repo.

### Metrics & Post-Mortem

Every completed feature generates a post-mortem with:
- Duration per phase
- Review round counts and rejection rates
- Bug density (bugs found per task)
- First-pass code review rate
- Lessons learned and recommendations

View aggregated metrics across all features:

```bash
/nloop-metrics                          # Overview dashboard
/nloop-metrics TICKET-ID               # Single feature metrics
/nloop-metrics --compare T-1 T-2       # Side-by-side comparison
```

### Performance Analysis

After code review approval, the **Perf Analyzer** scans for performance issues:

- **Bundle size**: new large dependencies, missing tree-shaking or code splitting
- **Database queries**: N+1 patterns, unbounded SELECTs, missing indexes
- **Algorithmic complexity**: nested loops, missing memoization, O(n^2) patterns
- **Memory/resources**: event listener leaks, unbounded caches, missing cleanup
- **Render performance**: unnecessary re-renders, missing virtualization
- **API/network**: waterfall requests, large payloads without pagination

Results are categorized as Critical/Warning/Info. Warnings don't block the pipeline — they're logged in `perf-report.md` for reference.

Skip performance analysis with tag `no-perf` or `docs-only`.

### Documentation & Changelog

The **Docs Writer** runs before PR creation and automatically:

- Generates a **changelog entry** following [Keep a Changelog](https://keepachangelog.com/) format
- Updates `CHANGELOG.md` under the `[Unreleased]` section
- Detects new API endpoints, components, config changes, and updates relevant docs
- Makes minimal, targeted README updates for user-facing features

Configure in `.nloop/config/nloop.yaml`:

```yaml
changelog:
  enabled: true
  file: "CHANGELOG.md"
  format: "keepachangelog"  # keepachangelog | conventional | simple
```

Skip docs with tag `no-docs`.

### Notifications

NLoop can send webhook notifications at key pipeline events to Slack, Discord, Teams, or any custom endpoint:

```yaml
# In nloop.yaml
notifications:
  enabled: true
  events: [workflow_started, workflow_completed, workflow_escalated, pr_created]

  slack:
    webhook_url: "https://hooks.slack.com/services/T00/B00/xxx"
    channel: "#dev-pipeline"
    mention_on_escalation: "@channel"

  discord:
    webhook_url: "https://discord.com/api/webhooks/123/abc"

  teams:
    webhook_url: "https://outlook.office.com/webhook/..."

  custom:
    url: "https://your-api.com/nloop-events"
    headers: { "Authorization": "Bearer xxx" }
```

| Event | Trigger |
|-------|---------|
| `workflow_started` | Pipeline begins |
| `workflow_completed` | Feature done, PR created |
| `workflow_escalated` | Human intervention needed |
| `workflow_failed` | Pipeline error |
| `pr_created` | PR opened on GitHub/Bitbucket |

Notifications are best-effort — webhook failures never block the pipeline.

### Git Platform Support

NLoop supports both **GitHub** and **Bitbucket** for PR creation:

```yaml
# In nloop.yaml
git_platform: github  # or bitbucket

github:
  default_reviewers: ["user1", "user2"]
  branch_prefix: "feature/"
  base_branch: "main"
  draft: false
  labels: ["enhancement"]
```

GitHub uses `gh` CLI (authenticate with `gh auth login`). Bitbucket uses the REST API with `BITBUCKET_TOKEN`.

## Project Structure

After running `/nloop-init`, your project gets:

```
your-project/
└── .nloop/
    ├── agents/           # Agent definitions (customizable .md files)
    ├── config/
    │   ├── nloop.yaml    # Global settings (git platform, models, polling)
    │   └── triggers.yaml # Auto-start rules for tickets
    ├── workflows/
    │   ├── default.yaml  # Full feature pipeline
    │   ├── bugfix.yaml   # Simplified bug fix pipeline
    │   ├── hotfix.yaml   # Minimal critical fix pipeline
    │   └── refactor.yaml # Refactoring pipeline (no QA)
    ├── engine/
    │   ├── state-schema.json
    │   └── templates/    # Templates for feature artifacts
    └── features/         # Runtime data (gitignored)
```

## Configuration

### Git Platform

Edit `.nloop/config/nloop.yaml`:

```yaml
# GitHub (recommended — uses gh CLI)
git_platform: github
github:
  default_reviewers: ["teammate1", "teammate2"]
  branch_prefix: "feature/"
  base_branch: "main"
  draft: false

# OR Bitbucket (uses REST API)
git_platform: bitbucket
bitbucket:
  base_url: "https://bitbucket.org"
  workspace: "your-team"
  repo: "your-repo"
  default_reviewers: ["username1"]
  branch_prefix: "feature/"
```

### YouTrack Integration

Run `/nloop-init --with-youtrack` or set up manually:

```bash
export YOUTRACK_TOKEN="your-permanent-token"
export YOUTRACK_BASE_URL="https://your-team.youtrack.cloud"
```

#### Polling Filters

Configure which tickets NLoop monitors using `/nloop-config polling` or edit `.nloop/config/nloop.yaml` directly:

```yaml
polling:
  enabled: true
  interval: 30m
  filters:
    project: ["MYPROJ"]           # YouTrack project IDs
    state: ["Open"]               # Ticket states
    type: ["Bug", "Feature"]      # Ticket types
    priority: []                  # Empty = all priorities
    tag: ["nloop"]                # Required tags
    assignee: ["Unassigned"]      # Filter by assignee
    custom_fields:                # YouTrack custom fields
      Sprint: "Sprint 42"
      Team: "Backend"
```

NLoop builds the YouTrack query automatically from these filters. Or use a raw query:

```yaml
polling:
  youtrack_query: "project: MYPROJ State: Open tag: nloop"  # Overrides filters
```

### Trigger Rules

Edit `.nloop/config/triggers.yaml` to control how polled tickets are handled:

```yaml
rules:
  - name: auto-start-tagged
    match:
      tags: [nloop-auto]
    action: auto_start

  - name: critical-needs-approval
    match:
      priority: [Critical, Urgent]
    action: require_approval

  - name: default
    match: {}
    action: require_approval
```

### Customizing Agents

Each agent is a `.md` file in `.nloop/agents/`. Edit the frontmatter to change the model, tools, or review rounds. Edit the body to change the agent's behavior, output format, and examples.

### Custom Workflows

Create new workflows in `.nloop/workflows/` or edit existing ones. Each workflow is a YAML state graph with:
- **nodes**: agent + action + skip conditions
- **edges**: transitions with conditions (approved, rejected, passed, failed, skipped)
- **defaults**: max review rounds, timeouts

## Commands

| Command | Description |
|---------|-------------|
| `/nloop-init` | Initialize NLoop in the current project |
| `/nloop-start TICKET-ID` | Start a feature pipeline |
| `/nloop-resume TICKET-ID` | Resume a paused/escalated feature |
| `/nloop-status [TICKET-ID]` | View dashboard or feature details |
| `/nloop-metrics [TICKET-ID]` | View metrics and trends |
| `/nloop-dryrun TICKET-ID` | Simulate a pipeline run without executing |
| `/nloop-watch TICKET-ID` | Live progress dashboard for a running feature |
| `/nloop-report` | Aggregated analytics — velocity, quality, trends |
| `/nloop-config [section]` | Interactive setup wizard for polling, git, notifications |
| `/nloop-poll` | Poll YouTrack for new tickets |

### `/nloop-dryrun` — Pipeline Simulation

Simulates the full NLoop pipeline **without spawning any agents or creating files**. Use it to validate your configuration, test workflow selection, preview skip conditions, and understand exactly what will happen before running `/nloop-start`.

**Syntax:**

```bash
/nloop-dryrun TICKET-ID [--tags tag1,tag2] [--type Bug|Feature|Task] [--workflow name]
```

**Flags:**

| Flag | Description |
|------|-------------|
| `--tags` | Simulate ticket tags (comma-separated). Used for workflow selection and skip conditions |
| `--type` | Simulate ticket type (`Bug`, `Feature`, `Task`) |
| `--workflow` | Force a specific workflow, skipping auto-selection |
| `--priority` | Simulate ticket priority (`Critical`, `Normal`, `Low`) |

If no flags are provided and YouTrack MCP is configured, NLoop will fetch real ticket metadata automatically.

**Examples:**

```bash
# Default workflow (feature ticket, no tags)
/nloop-dryrun PROJ-42

# Test bugfix workflow selection
/nloop-dryrun PROJ-43 --tags bugfix

# Hotfix — minimal pipeline
/nloop-dryrun PROJ-44 --tags hotfix

# Refactor with QA skipped (backend-only tag)
/nloop-dryrun PROJ-45 --tags refactor,backend-only

# Force a specific workflow regardless of tags
/nloop-dryrun PROJ-46 --workflow hotfix

# Simulate a Bug ticket type
/nloop-dryrun PROJ-47 --type Bug --tags backend-only
```

**What it shows:**

1. **Configuration Validation** — Checks `nloop.yaml`, all workflows, agents, and triggers for errors/warnings
2. **Workflow Selection** — Evaluates `workflow_mapping` rules against the ticket metadata and shows which rule matched
3. **Pipeline Simulation** — Walks the entire workflow graph node by node, showing:
   - Each node's agent and action
   - Skip conditions evaluated and their result
   - All possible branches at review/test nodes (approved, rejected, max_rounds_exceeded, passed, failed)
   - The "happy path" highlighted as the main flow
4. **Resource Estimate** — Best-case and worst-case agent calls, models used, parallel worktrees needed, artifacts produced
5. **Summary** — Total nodes, review points, parallel phases, git platform, and the branch name that would be created

**Example output:**

```
🔍 NLoop Dryrun — PROJ-45
══════════════════════════════════════════════════════

📋 Configuration Validation
  ✅ nloop.yaml v3 — valid
  ✅ 4 workflows found: default, bugfix, hotfix, refactor
  ✅ 10 agents defined
  ✅ Git platform: github (gh CLI)

🎯 Workflow Selection
  Tags: refactor, backend-only
  Rule matched: workflow_mapping[2] → tags: [refactor, tech-debt, cleanup]
  ✅ Selected workflow: refactor

🔄 Pipeline Simulation
  ┌─ brainstorm (tech-leader)
  ├─ plan (product-planner)
  ├─ review-plan (tech-leader) — max 3 rounds
  ├─ architecture (architect)
  ├─ review-spec (tech-leader) — max 3 rounds
  ├─ task-planning (project-manager)
  ├─ execute-tasks (project-manager) [PARALLEL]
  ├─ code-review (code-reviewer)
  ├─ unit-testing (unit-tester)
  │   ⏭️  qa-testing SKIPPED (refactor workflow + tag: backend-only)
  ├─ create-pr (tech-leader)
  ├─ post-mortem (tech-leader)
  └─ ✅ DONE

📊 Resource Estimates
  Agent calls (happy path):  11 nodes
  Agent calls (worst case):  20 nodes
  Skipped phases:            brainstorm-refinement, qa-testing
```

**When to use it:**

- Before running your first `/nloop-start` — validate the entire setup
- After editing workflows or config — verify changes don't break the graph
- When adding custom workflows — test that workflow selection rules match correctly
- When using skip conditions — confirm the right nodes are being skipped
- To compare workflows — run dryrun with different tags to see how pipelines differ

### `/nloop-watch` — Live Progress Dashboard

Real-time progress view for a running pipeline. Shows which node is executing, elapsed time per phase, and a live timeline of events.

```bash
/nloop-watch TICKET-ID
/nloop-watch TICKET-ID --tail 20    # Show last 20 events
```

**What it shows:**

- Pipeline progress bar with node states (completed, in-progress, pending, skipped)
- Elapsed time per phase
- Review round status and task breakdown
- Artifacts checklist (which files exist vs pending)
- Recent events log
- Status-specific views for completed/escalated/failed features

**Example:**

```
📍 Pipeline Progress

  ✅ brainstorm          tech-leader         2m 15s
  ✅ plan                product-planner     5m 42s
  ✅ review-plan         tech-leader         1m 30s    APPROVED (round 1)
  ✅ architecture        architect           8m 12s
  🔄 code-review        code-reviewer       --:--     IN PROGRESS
  ⬚  perf-analysis      perf-analyzer       --:--
  ⬚  unit-testing       unit-tester         --:--
  ⬚  docs-update        docs-writer         --:--

  Progress: 6/14 nodes (43%)
  ██████████░░░░░░░░░░░ 43%
```

### `/nloop-config` — Interactive Setup Wizard

Configure NLoop settings interactively. Asks questions one at a time with multiple choice and writes changes to the YAML files.

```bash
/nloop-config                    # Show summary + ask what to configure
/nloop-config polling            # Set up YouTrack polling filters
/nloop-config git                # Set up GitHub or Bitbucket
/nloop-config notifications      # Set up Slack/Discord/Teams webhooks
/nloop-config models             # Choose model per agent role
/nloop-config triggers           # Add/edit/remove trigger rules
/nloop-config all                # Full guided setup
```

**Polling example:**

```
/nloop-config polling

> Which YouTrack projects should NLoop monitor?
  Enter project IDs separated by comma, or leave empty for all.
  Current: (all projects)
  > MYPROJ, BACKEND

> Which ticket states?
  1. Open only (default)
  2. Open + In Progress
  3. Custom
  Current: Open
  > 1

> Which tags identify tickets for NLoop?
  Current: nloop
  > nloop, nloop-auto

> Filter by priority?
  1. All priorities (default)
  2. Critical + Major only
  3. Custom
  > 2

[NLoop Config] Polling filters updated:
  project: ["MYPROJ", "BACKEND"]
  state: ["Open"]
  tag: ["nloop", "nloop-auto"]
  priority: ["Critical", "Major"]

  Generated query: "project: MYPROJ,BACKEND State: Open tag: nloop,nloop-auto Priority: Critical,Major"
  Saved to .nloop/config/nloop.yaml
```

### `/nloop-report` — Aggregated Analytics

Generate reports across all completed features with velocity trends, quality metrics, and actionable recommendations.

```bash
/nloop-report                    # Last 7 days
/nloop-report --period month     # Last 30 days
/nloop-report --period all       # All time
/nloop-report --format json      # JSON output for integrations
```

**Sections:**

- **Velocity**: features completed, avg/median time, trend vs previous period, breakdown by workflow type
- **Quality**: first-pass code review rate, avg review rounds, bug density, escalation rate
- **Phase Timing**: average duration per phase, bottleneck detection, trend arrows
- **Agent Performance**: rejections by agent, review efficiency, bug attribution
- **Recommendations**: AI-generated actionable suggestions based on data patterns (e.g., "Plan rejection rate is 40% — consider more detailed brainstorming")

## Requirements

- **Claude Code** (latest version with plugin support)
- **Git** (for worktree-based parallelism)
- **gh CLI** (for GitHub PR creation — `gh auth login`)
- **Node.js** (optional, for YouTrack MCP server)

## License

MIT
