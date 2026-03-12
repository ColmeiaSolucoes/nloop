---
description: "Simulate a full NLoop pipeline run without executing any agents. Shows workflow selection, node sequence, skip conditions, and estimated flow."
argument-hint: "TICKET-ID [--tags tag1,tag2] [--type Bug|Feature] [--workflow name]"
---

# NLoop Dry Run — Pipeline Simulation

Simulate the full NLoop pipeline without spawning any agents or creating any files. This is useful for:
- Verifying which workflow will be selected for a ticket
- Seeing which nodes will be skipped
- Understanding the full pipeline flow before committing
- Validating workflow YAML configuration
- Testing skip conditions

## Invocation

```
/nloop-dryrun TICKET-ID
/nloop-dryrun TICKET-ID --tags bugfix,backend-only
/nloop-dryrun TICKET-ID --type Bug
/nloop-dryrun TICKET-ID --workflow hotfix
```

Arguments: $ARGUMENTS

**Important**: This command is READ-ONLY. Do NOT create any files, directories, or modify any state.

## Step 1: Parse Arguments

1. Extract TICKET-ID from arguments
2. Extract optional flags:
   - `--tags tag1,tag2` — simulate ticket tags (used for workflow selection and skip conditions)
   - `--type Bug|Feature|Task` — simulate ticket type
   - `--workflow name` — force a specific workflow (skip auto-selection)
   - `--priority Critical|Normal|Low` — simulate ticket priority
3. If no tags/type provided and YouTrack MCP is available, try to fetch real ticket metadata
4. If no metadata available, use empty tags/type and inform the user

## Step 2: Validate Configuration

Read and validate all config files. Report any issues:

1. **Config**: Read `.nloop/config/nloop.yaml`
   - Check version field
   - Check git_platform is set (github or bitbucket)
   - Check relevant platform config has required fields
   - Check workflow_mapping rules are valid
   - Report: `[OK]` or `[WARN] {issue}`

2. **Workflows**: Read all `.nloop/workflows/*.yaml`
   - Check each workflow has required fields (name, nodes, edges)
   - Check all edge references point to existing nodes
   - Check all nodes reference existing agent files
   - Check for unreachable nodes (no incoming edges)
   - Check for dead-end nodes (no outgoing edges, not terminal)
   - Report per workflow: `[OK]` or `[ERROR] {issue}`

3. **Agents**: Check all `.nloop/agents/*.md` exist and have valid frontmatter
   - Required frontmatter: name, tools, model
   - Check model is valid (opus, sonnet, haiku)
   - Report per agent: `[OK]` or `[WARN] {issue}`

4. **Triggers**: Read `.nloop/config/triggers.yaml`
   - Check rules have valid structure (match + action)
   - Report: `[OK]` or `[WARN] {issue}`

Display validation results:

```
[DryRun] Configuration Validation
  Config (nloop.yaml):     [OK]
  Workflow (default.yaml): [OK]
  Workflow (bugfix.yaml):  [OK]
  Workflow (hotfix.yaml):  [OK]
  Workflow (refactor.yaml):[OK]
  Agents (8 files):        [OK]
  Triggers:                [OK]
```

If any [ERROR] found, stop and display the issues.

## Step 3: Workflow Selection

Simulate the workflow selection logic:

1. Read `workflow_mapping` from config
2. Evaluate each rule against the simulated ticket metadata (tags, type, priority)
3. Display the result:

```
[DryRun] Workflow Selection
  Ticket:  {TICKET_ID}
  Tags:    {tags or "none"}
  Type:    {type or "unknown"}

  Evaluating workflow_mapping rules:
    Rule "hotfix" (tags: [hotfix, critical-fix]):     NO MATCH
    Rule "bugfix" (tags: [bugfix, bug]):              MATCHED  <--
    Rule "refactor" (tags: [refactor, tech-debt]):    (skipped, already matched)

  Selected workflow: bugfix
  Workflow file: .nloop/workflows/bugfix.yaml
```

If `--workflow` was specified, skip selection and show:
```
  Selected workflow: {name} (forced via --workflow flag)
```

## Step 4: Simulate Pipeline

Walk through the workflow graph node by node, simulating the orchestration loop:

1. Start at the first node
2. For each node:
   a. Check skip conditions (skip_if + global skip_conditions)
   b. Determine what the node would do
   c. Simulate the most likely outcome (approved for reviews, passed for tests)
   d. Resolve the next edge
3. Continue until reaching a terminal state

Display the simulation as a timeline:

```
[DryRun] Pipeline Simulation — {TICKET_ID} using workflow "{workflow_name}"

  Step  Node                    Agent              Action              Skip?   Estimated
  ────  ────────────────────    ─────────────────  ──────────────────  ──────  ─────────
   1    brainstorm              tech-leader        brainstorm          -       -> plan
   2    plan                    product-planner    create-plan         -       -> review-plan
   3    review-plan             tech-leader        review              -       -> architecture (if approved)
                                                                               -> plan (if rejected, max 4 rounds)
                                                                               -> escalate (if max rounds exceeded)
   4    architecture            architect          create-spec         -       -> review-spec
   5    review-spec             tech-leader        review              -       -> brainstorm-refinement (if approved)
   6    brainstorm-refinement   tech-leader        brainstorm-refine   -       -> task-planning
   7    task-planning           project-manager    create-tasks        -       -> execute-tasks
   8    execute-tasks           project-manager    dispatch-tasks      -       -> code-review (parallel: up to 3 agents)
   9    code-review             code-reviewer      review-code         -       -> unit-testing (if approved)
                                                                               -> execute-tasks (if rejected)
  10    unit-testing            unit-tester        run-tests           -       -> qa-testing (if passed)
                                                                               -> bug-fixing (if failed)
  11    qa-testing              qa-tester          visual-test         SKIP    -> create-pr (tag: backend-only)
  12    create-pr               tech-leader        create-pr           -       -> post-mortem
  13    post-mortem             tech-leader        post-mortem         -       -> done

  TERMINAL: done
```

For skipped nodes, show the reason:
```
  11    qa-testing              qa-tester          visual-test         SKIP    -> create-pr
        ^ Skipped: ticket has tag "backend-only" (matches skip_if: tag: backend-only)
```

## Step 5: Resource Estimate

Display estimated resource usage:

```
[DryRun] Resource Estimate

  Agents to spawn:     {n} (sequential) + up to {n} parallel developers
  Models used:         opus x{n} calls, sonnet x{n} calls
  Review rounds:       up to {max} per review node
  Parallel worktrees:  up to {max_concurrent_agents}
  Artifacts produced:  {list of .md files}
  Nodes skipped:       {n} ({list})

  Estimated pipeline:
    Best case:   {n} agent calls (all reviews approved first try, all tests pass)
    Worst case:  {n} agent calls (max review rounds, test failures + bug fix cycle)
```

## Step 6: Summary

```
[DryRun] Simulation Complete

  Workflow:         {name}
  Total nodes:      {n} ({n} will execute, {n} skipped)
  Review points:    {n} (max {max_rounds} rounds each)
  Parallel phases:  {n}
  Git platform:     {github|bitbucket}
  PR branch:        {branch_prefix}{TICKET_ID}

  Ready to run:     /nloop-start {TICKET_ID}
```

## Error Handling

- **Missing .nloop/ directory**: Display "NLoop not initialized. Run /nloop-init first."
- **Missing workflow file**: Display which workflow was selected but file not found
- **Invalid workflow (broken edges)**: Display the specific edge/node issue
- **Missing agent file**: Display which agent is referenced but not found

## Notes

- This command NEVER creates files, spawns agents, or modifies state
- It reads all configuration and simulates the pipeline path
- The simulation assumes the "happy path" (approvals, passing tests) for the main flow, but shows all possible branches at review/test nodes
- Use `--tags` to test how different ticket metadata affects workflow selection and skip conditions
