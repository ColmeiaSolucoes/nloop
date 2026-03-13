# Changelog

All notable changes to NLoop will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0] — 2026-03-13

### Added
- `/nloop-abort` command — cancel running pipelines, cleanup worktrees, send notifications
- `also_runs` processing in orchestrator — supplementary agent actions (e.g., help article generation after docs update)
- YouTrack auto-status updates — ticket moves to "In Progress" on start, "Done" on complete, with comments on escalation/failure
- Configurable `youtrack_status` mapping in nloop.yaml
- Worktree merge/cleanup lifecycle — full Phase A-D cycle (prepare branch, dispatch, merge back, cleanup)
- Branch prefix per workflow type — `feature/`, `bugfix/`, `hotfix/`, `refactor/` auto-selected
- `WARNING` condition for perf-analysis results (non-blocking, pipeline continues)
- `COMPLETED` condition for artifact-producing nodes
- Model usage tracking in `state.metrics.models_used` for cost analysis
- All 3 `escalation_action` modes now implemented: `pause`, `notify`, `skip`

### Fixed
- `state-schema.json` now matches `feature-state.json` template (added `ticket_tags`, `metrics`, `docs`, `notifications_sent`, `models_used`)
- Code-reviewer agent now has `Write` tool (was missing — couldn't save review files)
- Duplicate/ambiguous edges in all 4 workflows — perf-analysis uses `passed`/`warning`/`skipped`; docs-update uses `completed`/`skipped`
- Progress bar in `/nloop-status` is now dynamic (reads workflow YAML instead of hardcoded 13 steps)
- `feature-summary.md` template updated with all 12 artifacts
- Step numbering in `nloop-start.md` corrected (3.1-3.13 sequential)
- Added `github` to plugin.json keywords

## [1.0.0] — 2026-03-12

### Added
- Initial release of NLoop multi-agent orchestration plugin
- 10 specialized agents: tech-leader, product-planner, architect, project-manager, developer, code-reviewer, perf-analyzer, unit-tester, qa-tester, docs-writer
- 4 workflow types: default (full feature), bugfix, hotfix, refactor
- Declarative YAML state graph with conditional edges and review loops
- Parallel task execution via git worktrees
- Interactive brainstorm via `/brainstorming` skill (inline nodes)
- Autonomous pipeline execution — no user confirmation between nodes
- YouTrack MCP server for ticket management
- Smart skip conditions (per-node and global)
- Webhook notifications (Slack, Discord, Teams, custom)
- Performance analysis agent (bundle size, N+1 queries, complexity, memory, render, API)
- Documentation writer with help center article generation
- Post-mortem with metrics appended to global history
- 11 commands: init, start, resume, status, metrics, dryrun, watch, report, config, poll, abort
- Structured polling filters with auto-built YouTrack queries
- Interactive `/nloop-config` wizard for all settings
- `/nloop-dryrun` pipeline simulation
- `/nloop-watch` live progress dashboard
- `/nloop-report` aggregated analytics with recommendations engine
- GitHub and Bitbucket PR creation support
- Trigger rules for auto-start vs require-approval
