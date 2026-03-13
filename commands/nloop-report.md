---
description: "Generate aggregated reports across NLoop features — weekly summary, velocity trends, bug patterns, and agent performance."
argument-hint: "[--period week|month|all] [--format markdown|json]"
---

# NLoop Report — Aggregated Analytics

Generate a comprehensive report across all completed NLoop features. Shows team velocity, quality trends, common patterns, and agent performance.

## Invocation

```
/nloop-report                          # Default: last 7 days
/nloop-report --period week            # Last 7 days
/nloop-report --period month           # Last 30 days
/nloop-report --period all             # All time
/nloop-report --format json            # Output as JSON (for integrations)
```

Arguments: $ARGUMENTS

## Step 1: Parse Arguments

1. Extract `--period` (default: `week`)
   - `week` → last 7 days
   - `month` → last 30 days
   - `all` → no date filter
2. Extract `--format` (default: `markdown`)

## Step 2: Collect Data

1. **Read metrics history**: `.nloop/metrics-history.jsonl`
   - Each line is a JSON object with feature metrics (from post-mortem)
   - Filter by date range based on `--period`
   - If file doesn't exist or is empty, display "No completed features found. Metrics are generated automatically when features complete."

2. **Read active features**: Scan `.nloop/features/*/state.json`
   - Count features by status: `in_progress`, `escalated`, `completed`, `failed`, `aborted`
   - Get current node for in-progress features

3. **Read post-mortems**: Scan `.nloop/features/*/post-mortem.md` for qualitative data

## Step 3: Calculate Metrics

### Velocity Metrics
- **Features completed**: count in period
- **Average time to completion**: mean of `duration_total_s` across features
- **Median time to completion**: median (more robust than average)
- **Throughput trend**: compare current period vs previous period (up/down/stable)

### Quality Metrics
- **First-pass code review rate**: % of features where code-review approved on round 1
- **Average review rounds**: mean across plan, spec, and code reviews
- **Bug density**: total bugs found / total tasks implemented
- **Bug source distribution**: % from unit tests vs QA tests
- **Escalation rate**: % of features that hit escalation

### Workflow Distribution
- **Features by workflow**: count per workflow type (default, bugfix, hotfix, refactor)
- **Features by workflow outcome**: completed vs escalated vs failed per workflow
- **Average time by workflow**: which workflow is fastest/slowest

### Agent Performance
- **Rejections by agent**: which agent's outputs get rejected most
- **Review rounds by reviewer**: does the tech-leader approve faster on certain artifact types?
- **Bug attribution**: which tasks/areas produce the most bugs

### Phase Timing
- **Average time per phase**: brainstorm, plan, architecture, implementation, review, testing
- **Bottleneck detection**: which phase takes longest on average
- **Phase time trend**: getting faster or slower over time

## Step 4: Generate Report

### Markdown Format (default)

Display:

```
📊 NLoop Report — {period_label}
══════════════════════════════════════════════════════

📅 Period: {start_date} → {end_date}
📦 Features: {completed} completed, {in_progress} in progress, {escalated} escalated

────────────────────────────────────────────────────
🚀 Velocity
────────────────────────────────────────────────────

  Features completed:      {n}
  Avg time to completion:  {duration}
  Median time:             {duration}
  Trend vs previous:       {↑ n% faster | ↓ n% slower | → stable}

  By workflow:
    default:  {n} features, avg {duration}
    bugfix:   {n} features, avg {duration}
    hotfix:   {n} features, avg {duration}
    refactor: {n} features, avg {duration}

────────────────────────────────────────────────────
✅ Quality
────────────────────────────────────────────────────

  First-pass code review:  {n}% ({n}/{total})
  Avg review rounds:       plan {n}, spec {n}, code {n}
  Bug density:             {n} bugs per task
  Escalation rate:         {n}% ({n}/{total})

  Bugs by source:
    Unit tests:  {n} ({percent}%)
    QA tests:    {n} ({percent}%)

  Top bug categories:
    1. {category}: {n} bugs
    2. {category}: {n} bugs
    3. {category}: {n} bugs

────────────────────────────────────────────────────
⏱️  Phase Timing (averages)
────────────────────────────────────────────────────

  Phase            Avg Duration    Trend
  ─────────────    ────────────    ─────
  Brainstorm       {time}          {↑↓→}
  Planning         {time}          {↑↓→}
  Architecture     {time}          {↑↓→}
  Implementation   {time}          {↑↓→}
  Code Review      {time}          {↑↓→}
  Testing          {time}          {↑↓→}
  Perf Analysis    {time}          {↑↓→}
  Docs Update      {time}          {↑↓→}

  🔴 Bottleneck: {phase} (accounts for {n}% of total time)

────────────────────────────────────────────────────
🤖 Agent Performance
────────────────────────────────────────────────────

  Agent               Tasks    Rejections    Avg Rounds
  ──────────────────   ─────    ──────────    ──────────
  product-planner      {n}      {n} ({%})     {n}
  architect            {n}      {n} ({%})     {n}
  developer            {n}      {n} ({%})     {n}
  code-reviewer        {n}      -             -

  💡 Insight: {actionable insight, e.g., "architect specs are approved 80% on first round — consider reducing max_rounds from 4 to 2"}

────────────────────────────────────────────────────
📋 Active Features
────────────────────────────────────────────────────

  Ticket         Workflow    Current Node       Duration
  ────────────   ─────────   ──────────────     ────────
  {TICKET_ID}    {workflow}  {current_node}     {elapsed}

────────────────────────────────────────────────────
💡 Recommendations
────────────────────────────────────────────────────

  Based on the data, here are actionable recommendations:

  1. {recommendation}
  2. {recommendation}
  3. {recommendation}
```

### JSON Format

If `--format json`, output a structured JSON object with all the same data:
```json
{
  "period": { "start": "...", "end": "...", "label": "week" },
  "velocity": { "completed": 0, "avg_duration_s": 0, "median_duration_s": 0, "trend_pct": 0 },
  "quality": { "first_pass_rate": 0, "avg_review_rounds": {}, "bug_density": 0, "escalation_rate": 0 },
  "phase_timing": { "brainstorm": 0, "plan": 0 },
  "agent_performance": [],
  "active_features": [],
  "recommendations": []
}
```

## Step 5: Recommendations Engine

Generate 2-4 actionable recommendations based on data patterns:

- **High rejection rate on plans**: "Consider more detailed brainstorming before planning. Plan rejection rate is {n}%, above the 20% threshold."
- **Slow implementation phase**: "Implementation is the bottleneck at {n}% of total time. Consider increasing `max_concurrent_agents` from {current} to {suggested}."
- **Low first-pass code review**: "Only {n}% of code reviews pass on first round. Consider adding a self-review checklist to the developer agent."
- **QA finding many bugs**: "QA is catching {n} bugs per feature. Consider adding more specific acceptance criteria in task planning."
- **Hotfix frequency high**: "{n}% of features are hotfixes. Consider investigating root causes to reduce production issues."
- **Escalation rate high**: "Escalation rate is {n}%. Consider increasing `max_review_rounds` or adding more specific review criteria."

## Error Handling

- **No metrics file**: "No metrics data found. Metrics are generated when features complete via post-mortem. Run `/nloop-start` to process a feature."
- **No completed features in period**: "No features completed in the last {period}. Showing all-time data instead."
- **Corrupted metrics line**: Skip and warn: "Skipped 1 corrupted entry in metrics-history.jsonl"
