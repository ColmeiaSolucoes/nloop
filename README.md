# NLoop — Multi-Agent Orchestration for Claude Code

A multi-agent orchestration system that automates the full software development lifecycle — from ticket intake (YouTrack) through planning, architecture, implementation, code review, testing, and PR creation (GitHub/Bitbucket).

NLoop models a virtual software team with 8 specialized agents that communicate through a declarative YAML state graph workflow with review loops, parallel execution via git worktrees, smart skip conditions, and automatic post-mortem metrics.

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

# Resume a paused/crashed feature
/nloop-resume TICKET-ID

# Check status dashboard
/nloop-status

# Detailed view of a feature
/nloop-status TICKET-ID

# View metrics and trends
/nloop-metrics

# Poll YouTrack for new tickets
/nloop-poll

# Auto-poll every 30 minutes
/loop 30m /nloop-poll
```

## How It Works

NLoop orchestrates a pipeline of specialized AI agents through a state graph:

```
Ticket → Brainstorm → Plan → Review → Architecture → Review → Refinement
    → Task Planning → Parallel Implementation → Code Review → Tests → PR → Post-Mortem
```

Each step is handled by a specialized agent:

| Agent | Role | Model |
|-------|------|-------|
| **Tech Leader** | Orchestrates, reviews, escalates, post-mortem | opus |
| **Product Planner** | Decomposes ideas, researches, creates plans | sonnet |
| **Architect** | Technical specification and design | opus |
| **Project Manager** | EPICs, tasks, dependency graphs | sonnet |
| **Developer** | Implements tasks (parallel via worktrees) | sonnet |
| **Code Reviewer** | Reviews code quality and security | sonnet |
| **Unit Tester** | Runs/writes unit and integration tests | sonnet |
| **QA Tester** | Visual/E2E testing via Chrome MCP | sonnet |

### Workflow Selection by Ticket Type

NLoop automatically selects the right workflow based on ticket tags:

| Workflow | When | What it skips |
|----------|------|---------------|
| **default** | Features, new functionality | Nothing — full pipeline |
| **bugfix** | Tags: `bugfix`, `bug` | Plan, Architecture, Spec review |
| **hotfix** | Tags: `hotfix`, `critical-fix` | Plan, Spec, Task planning, QA |
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
  ✅ nloop.yaml v2 — valid
  ✅ 4 workflows found: default, bugfix, hotfix, refactor
  ✅ 7 agents defined
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

## Requirements

- **Claude Code** (latest version with plugin support)
- **Git** (for worktree-based parallelism)
- **gh CLI** (for GitHub PR creation — `gh auth login`)
- **Node.js** (optional, for YouTrack MCP server)

## License

MIT
