# NLoop — Multi-Agent Orchestration System

A multi-agent orchestration system built as a Claude Code skill/agent hybrid that automates the full software development lifecycle — from ticket intake (YouTrack) through planning, architecture, implementation, code review, testing, and PR creation (Bitbucket).

## Quick Start

```bash
# Start a feature manually
/nloop-start TICKET-ID

# Resume a paused/crashed feature
/nloop-resume TICKET-ID

# Check status of all features
/nloop-status

# Enable polling (runs every 30min)
/loop 30m /nloop-poll
```

## Architecture

```
.nloop/
├── agents/           # Agent definitions (.md with frontmatter + prompt + examples)
├── workflows/        # Workflow definitions (YAML state graphs)
├── config/           # Global settings + trigger rules
├── skills/           # Claude Code skills (entry points)
├── mcp/youtrack/     # YouTrack MCP server
├── engine/           # Orchestrator core + state schema + templates
└── features/         # Active feature workspaces (runtime)
```

## Agents

| Agent | Role | Model |
|-------|------|-------|
| Tech Leader | Orchestrates, reviews, escalates | opus |
| Product Planner | Decomposes ideas, researches, creates plans | sonnet |
| Architect | Technical specification and design | opus |
| Project Manager | EPICs, tasks, dependency graphs | sonnet |
| Developer | Implements tasks (parallel via worktrees) | sonnet |
| Code Reviewer | Reviews code quality and security | sonnet |
| Unit Tester | Runs/writes unit and integration tests | sonnet |
| QA Tester | Visual/E2E testing via Chrome MCP | sonnet |

## Configuration

- `config/nloop.yaml` — Global settings (models, polling, parallel execution, Bitbucket)
- `config/triggers.yaml` — Rules for auto-starting vs requiring approval for tickets
- `workflows/default.yaml` — The default development workflow (state graph)
- `agents/*.md` — Individual agent behavior (edit to customize)
