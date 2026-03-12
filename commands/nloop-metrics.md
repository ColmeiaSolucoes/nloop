---
description: "Show aggregated metrics across all NLoop features — duration, review efficiency, bug density, and trends."
argument-hint: "[TICKET-ID | --all | --compare TICKET-1 TICKET-2]"
---

# NLoop Metrics Dashboard

You analyze and display metrics from NLoop feature executions to help teams understand performance, quality trends, and bottlenecks.

## Invocation

```
/nloop-metrics                        # Summary of all features
/nloop-metrics TICKET-ID              # Detailed metrics for one feature
/nloop-metrics --compare T-1 T-2      # Compare two features side by side
```

Arguments: $ARGUMENTS

## Data Sources

Metrics come from two places:
1. **Per-feature**: `.nloop/features/{TICKET-ID}/post-mortem.md` and `state.json`
2. **Aggregated**: `.nloop/metrics-history.jsonl` (one JSON line per completed feature)

## Mode 1: Overview (no args or --all)

### Step 1: Load History

Read `.nloop/metrics-history.jsonl`. Each line is a JSON object with:
```json
{
  "ticket_id": "PROJ-42",
  "workflow": "default",
  "started_at": "2026-03-01T10:00:00Z",
  "completed_at": "2026-03-01T14:30:00Z",
  "duration_s": 16200,
  "phases": { "brainstorm": 300, "plan": 1200, ... },
  "review_rounds": { "plan": 2, "spec": 1, "code": 1 },
  "tasks": { "total": 6, "completed": 6 },
  "bugs": { "unit": 2, "qa": 1 },
  "first_pass_approval": false
}
```

### Step 2: Calculate Aggregates

- **Total features completed**: count of entries
- **Average duration**: mean of duration_s
- **Average review rounds**: mean per artifact type
- **First-pass approval rate**: % of features where code review approved on round 1
- **Bug density**: average bugs per task
- **Workflow distribution**: count per workflow type
- **Bottleneck phase**: which phase takes the longest on average

### Step 3: Display Dashboard

```
+======================================================================+
|                       NLOOP METRICS                                   |
|                       {date range}                                    |
+======================================================================+
|                                                                       |
|  OVERVIEW                                                             |
|  --------                                                             |
|  Features completed:  {n}                                             |
|  Average duration:    {time}                                          |
|  Total time saved:    ~{estimate}  (vs manual estimate)               |
|                                                                       |
|  QUALITY                                                              |
|  -------                                                              |
|  First-pass code review rate:  {n}%                                   |
|  Avg review rounds (plan):     {n}                                    |
|  Avg review rounds (spec):     {n}                                    |
|  Avg review rounds (code):     {n}                                    |
|  Avg bugs per feature:         {n}                                    |
|  Bug density (bugs/task):      {n}                                    |
|                                                                       |
|  BOTTLENECKS                                                          |
|  -----------                                                          |
|  Slowest phase:    {phase} (avg {time})                               |
|  Most rejections:  {phase} (avg {n} rounds)                           |
|  Most bugs from:   {unit|qa} ({n} avg)                                |
|                                                                       |
|  WORKFLOW USAGE                                                       |
|  --------------                                                       |
|  default:   {n} features  ({n}%)                                      |
|  bugfix:    {n} features  ({n}%)                                      |
|  hotfix:    {n} features  ({n}%)                                      |
|  refactor:  {n} features  ({n}%)                                      |
|                                                                       |
|  TREND (last 10 features)                                             |
|  ---------                                                            |
|  Duration:    {sparkline or trend arrow}                               |
|  Bug density: {sparkline or trend arrow}                               |
|  Review rds:  {sparkline or trend arrow}                               |
|                                                                       |
+======================================================================+
```

## Mode 2: Single Feature (/nloop-metrics TICKET-ID)

Read `.nloop/features/{TICKET-ID}/post-mortem.md` and display it formatted.

If post-mortem doesn't exist, read `state.json` and `logs/events.jsonl` to calculate metrics on the fly.

## Mode 3: Compare (/nloop-metrics --compare T-1 T-2)

Display side-by-side comparison:

```
+================================+================================+
|  {TICKET-1}                     |  {TICKET-2}                    |
+================================+================================+
|  Workflow: {type}               |  Workflow: {type}              |
|  Duration: {time}               |  Duration: {time}              |
|  Tasks:    {n}                  |  Tasks:    {n}                 |
|  Bugs:     {n}                  |  Bugs:     {n}                 |
|  Reviews:  plan {n} spec {n}    |  Reviews:  plan {n} spec {n}  |
|  1st pass: {yes/no}             |  1st pass: {yes/no}            |
+================================+================================+
```

## Edge Cases

- **No metrics history**: Display "No completed features yet. Metrics will appear after the first feature completes."
- **Feature not found**: Display error with available feature IDs
- **Partial data**: Calculate what's available, mark missing as "N/A"
