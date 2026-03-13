---
description: "Interactive configuration wizard for NLoop settings. Set up polling filters, git platform, notifications, models, and trigger rules."
argument-hint: "[section] — polling | git | notifications | models | triggers | all"
---

# NLoop Config — Interactive Setup Wizard

Configure NLoop settings interactively. Reads the current config, asks questions with multiple choice, and writes the changes back to the YAML files.

## Invocation

```
/nloop-config                    # Show current config summary + ask what to configure
/nloop-config polling            # Configure polling filters
/nloop-config git                # Configure git platform (GitHub/Bitbucket)
/nloop-config notifications      # Configure webhook notifications
/nloop-config models             # Configure model per agent role
/nloop-config triggers           # Configure trigger rules
/nloop-config all                # Full guided setup
```

Arguments: $ARGUMENTS

## Step 1: Load Current Config

1. Read `.nloop/config/nloop.yaml`
2. Read `.nloop/config/triggers.yaml`
3. If no argument provided, show current config summary and ask which section to configure:

```
[NLoop Config] Current configuration:

  Polling:        enabled, interval 30m
  Filters:        state: Open, tag: nloop
  Git platform:   github (gh CLI)
  Notifications:  disabled
  Models:         opus (orchestrator, architect), sonnet (others)
  Trigger rules:  3 rules configured

Which section do you want to configure?
  1. Polling filters (YouTrack query)
  2. Git platform (GitHub/Bitbucket)
  3. Notifications (Slack/Discord/Teams)
  4. Models (per agent role)
  5. Trigger rules
  6. All (full guided setup)
```

---

## Section: Polling Filters

Goal: Build the YouTrack polling query by asking structured questions.

### Questions (ask one at a time):

**Q1: Project filter**
```
Which YouTrack projects should NLoop monitor?
  Enter project IDs separated by comma, or leave empty for all projects.
  Example: MYPROJ, BACKEND, FRONTEND

  Current: {current value or "all projects"}
  >
```

**Q2: State filter**
```
Which ticket states should NLoop look for?
  1. Open only (default)
  2. Open + In Progress
  3. Custom states

  Current: {current value}
  >
```

**Q3: Type filter**
```
Which ticket types?
  1. All types (default)
  2. Bug only
  3. Feature only
  4. Bug + Feature
  5. Custom types

  Current: {current value or "all"}
  >
```

**Q4: Priority filter**
```
Filter by priority?
  1. All priorities (default)
  2. Critical + Major only
  3. Critical only
  4. Custom priorities

  Current: {current value or "all"}
  >
```

**Q5: Tag filter**
```
Which tags identify tickets for NLoop?
  Enter tags separated by comma.
  Tip: use "nloop" as the default tag to mark tickets for processing.

  Current: {current value}
  >
```

**Q6: Assignee filter**
```
Filter by assignee?
  1. Any assignee (default)
  2. Unassigned only (free backlog)
  3. Specific assignees

  Current: {current value or "any"}
  >
```

**Q7: Custom fields**
```
Any custom YouTrack fields to filter by?
  Enter as key=value pairs separated by comma, or leave empty.
  Example: Sprint=Sprint 42, Team=Backend

  Current: {current value or "none"}
  >
```

**Q8: Polling interval**
```
How often should NLoop poll for new tickets?
  1. Every 15 minutes
  2. Every 30 minutes (default)
  3. Every 1 hour
  4. Custom interval

  Current: {current value}
  >
```

### Apply Changes

After all questions:

1. Update `polling.filters` in `.nloop/config/nloop.yaml` with the user's answers
2. Clear `polling.youtrack_query` (since we're using structured filters)
3. Show the resulting config:

```
[NLoop Config] Polling filters updated:

  polling:
    enabled: true
    interval: 30m
    filters:
      project: ["MYPROJ"]
      state: ["Open"]
      type: ["Bug", "Feature"]
      priority: []
      tag: ["nloop"]
      assignee: ["Unassigned"]
      custom_fields: {}

  Generated YouTrack query:
    "project: MYPROJ State: Open Type: Bug,Feature tag: nloop Assignee: Unassigned"

  Saved to .nloop/config/nloop.yaml
```

### Query Builder Logic

Build the YouTrack query string from structured filters:

```
query = ""
if filters.project:     query += "project: {join(filters.project, ',')} "
if filters.state:       query += "State: {join(filters.state, ',')} "
if filters.type:        query += "Type: {join(filters.type, ',')} "
if filters.priority:    query += "Priority: {join(filters.priority, ',')} "
if filters.tag:         query += "tag: {join(filters.tag, ',')} "
if filters.assignee:    query += "Assignee: {join(filters.assignee, ',')} "
for key, value in filters.custom_fields:
  query += "{key}: {value} "
```

If `polling.youtrack_query` is not empty, it takes precedence over structured filters.

---

## Section: Git Platform

**Q1: Platform**
```
Which git platform do you use?
  1. GitHub (uses gh CLI)
  2. Bitbucket (uses REST API)

  Current: {current value}
  >
```

**If GitHub:**

**Q2:** `Default reviewers?` (comma-separated usernames, or empty)
**Q3:** `Branch prefix?` (default: "feature/")
**Q4:** `Base branch?` (default: "main")
**Q5:** `Create PRs as draft?` (yes/no, default: no)
**Q6:** `Labels to add to PRs?` (comma-separated, or empty)

**If Bitbucket:**

**Q2:** `Bitbucket base URL?` (default: "https://bitbucket.org")
**Q3:** `Workspace?` (required)
**Q4:** `Repository slug?` (required)
**Q5:** `Default reviewers?` (comma-separated usernames)
**Q6:** `Branch prefix?` (default: "feature/")

Apply and show the result.

---

## Section: Notifications

**Q1:**
```
Enable webhook notifications?
  1. Yes
  2. No (default)

  Current: {current value}
  >
```

If yes:

**Q2:** `Which events?` (multi-select: workflow_started, workflow_completed, workflow_escalated, workflow_failed, pr_created)

**Q3:**
```
Which platforms do you want to notify?
  1. Slack
  2. Discord
  3. Microsoft Teams
  4. Custom webhook
  (Enter numbers separated by comma)
  >
```

For each selected platform, ask for the webhook URL and platform-specific settings.

Apply and show the result.

---

## Section: Models

```
Configure which Claude model each agent role uses:

  Role              Current     Options
  ────────────────  ──────────  ───────────────
  orchestrator      {value}     opus | sonnet
  planner           {value}     opus | sonnet
  architect         {value}     opus | sonnet
  manager           {value}     opus | sonnet
  developer         {value}     opus | sonnet
  reviewer          {value}     opus | sonnet
  tester            {value}     opus | sonnet
  analyzer          {value}     opus | sonnet
  documenter        {value}     opus | sonnet

Enter the roles you want to change as: role=model
Example: developer=opus, reviewer=opus
Or press Enter to keep current settings.
>
```

Apply and show the result.

---

## Section: Triggers

Show current rules and offer to add/edit/remove:

```
[NLoop Config] Current trigger rules:

  #  Name                    Match                       Action
  ─  ──────────────────────  ──────────────────────────  ────────────────
  1  auto-start-tagged       tags: [nloop-auto]          auto_start
  2  critical-needs-approval priority: [Critical,Urgent] require_approval
  3  default                 {} (catch-all)              require_approval

What do you want to do?
  1. Add a new rule
  2. Edit an existing rule
  3. Remove a rule
  4. Done
>
```

**Add rule:**
- Ask for: name, match criteria (tags, priority, project, type), action (auto_start, require_approval, ignore)
- Insert before the catch-all rule (last rule should always be catch-all)

**Edit rule:**
- Ask which rule number to edit
- Show current values, ask for new values

**Remove rule:**
- Ask which rule number to remove
- Don't allow removing the catch-all (last rule)

Apply changes to `.nloop/config/triggers.yaml` and show the result.

---

## Important Rules

1. **Ask one question at a time** — don't dump all questions at once
2. **Show current value** for each question so the user knows what's set
3. **Accept Enter for defaults** — pressing Enter keeps the current value
4. **Validate input** — check that project IDs, usernames, URLs are reasonable
5. **Show the result** after each section — display the updated YAML and confirm it was saved
6. **Never break existing config** — read the full file, update only the relevant section, write back
