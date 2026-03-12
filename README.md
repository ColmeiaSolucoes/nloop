# NLoop — Multi-Agent Orchestration for Claude Code

A multi-agent orchestration system that automates the full software development lifecycle — from ticket intake (YouTrack) through planning, architecture, implementation, code review, testing, and PR creation (Bitbucket).

NLoop models a virtual software team with 8 specialized agents that communicate through a declarative YAML state graph workflow with review loops, parallel execution via git worktrees, and human escalation.

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

# Poll YouTrack for new tickets
/nloop-poll

# Auto-poll every 30 minutes
/loop 30m /nloop-poll
```

## How It Works

NLoop orchestrates a pipeline of specialized AI agents through a state graph:

```
Ticket → Brainstorm → Plan → Review → Architecture → Review → Refinement
    → Task Planning → Parallel Implementation → Code Review → Tests → PR
```

Each step is handled by a specialized agent:

| Agent | Role | Model |
|-------|------|-------|
| **Tech Leader** | Orchestrates, reviews, escalates | opus |
| **Product Planner** | Decomposes ideas, researches, creates plans | sonnet |
| **Architect** | Technical specification and design | opus |
| **Project Manager** | EPICs, tasks, dependency graphs | sonnet |
| **Developer** | Implements tasks (parallel via worktrees) | sonnet |
| **Code Reviewer** | Reviews code quality and security | sonnet |
| **Unit Tester** | Runs/writes unit and integration tests | sonnet |
| **QA Tester** | Visual/E2E testing via Chrome MCP | sonnet |

### Review Loops

The Tech Leader reviews plans and specs with up to 4 rounds of feedback. If an agent's output is rejected, it goes back for revision with specific feedback. After max rounds, the pipeline escalates to a human.

### Parallel Execution

The Project Manager breaks specs into task groups with dependency graphs. Independent tasks run in parallel using git worktrees — each developer agent works in its own isolated copy of the repo.

### Workflow as Code

The entire pipeline is defined in `.nloop/workflows/default.yaml` — a declarative state graph with nodes (agents) and edges (transitions with conditions). You can customize the workflow, add new agents, or modify the review logic by editing YAML.

## Project Structure

After running `/nloop-init`, your project gets:

```
your-project/
└── .nloop/
    ├── agents/           # Agent definitions (customizable .md files)
    │   ├── tech-leader.md
    │   ├── product-planner.md
    │   ├── architect.md
    │   ├── project-manager.md
    │   ├── developer.md
    │   ├── code-reviewer.md
    │   ├── unit-tester.md
    │   └── qa-tester.md
    ├── config/
    │   ├── nloop.yaml    # Global settings (models, Bitbucket, polling)
    │   └── triggers.yaml # Auto-start rules for tickets
    ├── workflows/
    │   └── default.yaml  # The development pipeline (state graph)
    ├── engine/
    │   ├── state-schema.json
    │   └── templates/    # Templates for feature artifacts
    └── features/         # Runtime data (one dir per ticket, gitignored)
```

## Configuration

### Bitbucket Integration

Edit `.nloop/config/nloop.yaml`:

```yaml
bitbucket:
  base_url: "https://bitbucket.org"
  workspace: "your-team"
  repo: "your-repo"
  default_reviewers: ["username1", "username2"]
  branch_prefix: "feature/"
```

Set your token:
```bash
export BITBUCKET_TOKEN="your-app-password"
```

### YouTrack Integration

Run `/nloop-init --with-youtrack` or set up manually:

```bash
export YOUTRACK_TOKEN="your-permanent-token"
export YOUTRACK_BASE_URL="https://your-team.youtrack.cloud"
```

### Trigger Rules

Edit `.nloop/config/triggers.yaml` to control how tickets are handled:

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

Each agent is a `.md` file in `.nloop/agents/`. Edit the frontmatter to change the model, tools, or review rounds. Edit the body to change the agent's behavior and output format.

### Custom Workflows

Edit `.nloop/workflows/default.yaml` to change the pipeline. You can:
- Add or remove nodes (agents/actions)
- Change edge conditions and flow
- Adjust max review rounds per node
- Add new terminal states

## Commands

| Command | Description |
|---------|-------------|
| `/nloop-init` | Initialize NLoop in the current project |
| `/nloop-start TICKET-ID` | Start a feature pipeline |
| `/nloop-resume TICKET-ID` | Resume a paused/escalated feature |
| `/nloop-status [TICKET-ID]` | View dashboard or feature details |
| `/nloop-poll` | Poll YouTrack for new tickets |

## Requirements

- **Claude Code** (latest version with plugin support)
- **Git** (for worktree-based parallelism)
- **Node.js** (optional, for YouTrack MCP server)

## License

MIT
