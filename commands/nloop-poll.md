---
description: "Poll YouTrack for new tickets and process them according to trigger rules. Use with /loop for periodic polling."
argument-hint: ""
---

# NLoop Poller — Check YouTrack for New Tickets

You poll YouTrack for new tickets and decide whether to auto-start them or queue them for approval based on trigger rules.

## Invocation

```
/nloop-poll                  # One-time poll
/loop 30m /nloop-poll        # Poll every 30 minutes
```

## Step 1: Load Configuration

1. Read `.nloop/config/nloop.yaml` for:
   - `polling.enabled` — if false, skip polling
   - `polling.youtrack_query` — raw query (takes precedence if not empty)
   - `polling.filters` — structured filters to build the query from
2. Read `.nloop/config/triggers.yaml` for trigger rules

If polling is disabled, display "Polling is disabled in nloop.yaml" and stop.

## Step 1.5: Build YouTrack Query

If `polling.youtrack_query` is not empty, use it directly.

Otherwise, build the query from `polling.filters`:

```
query = ""
if filters.project:     query += "project: {join with ','} "
if filters.state:       query += "State: {join with ','} "
if filters.type:        query += "Type: {join with ','} "
if filters.priority:    query += "Priority: {join with ','} "
if filters.tag:         query += "tag: {join with ','} "
if filters.assignee:    query += "Assignee: {join with ','} "
for key, value in filters.custom_fields:
  query += "{key}: {value} "
```

Display: `[NLoop Poll] Query: {query}`

## Step 2: Fetch New Tickets

1. Call `youtrack_list_tickets` with the built query
2. For each ticket returned, check if it's already being processed:
   - Check if `.nloop/features/{ticket_id}/` directory exists
   - If yes: skip (already in pipeline)
   - If no: this is a new ticket -> process it

If no new tickets found, display:
```
[NLoop Poll] No new tickets found. ({timestamp})
```

## Step 3: Evaluate Trigger Rules

For each new ticket, evaluate trigger rules from `triggers.yaml`:

### Rule Evaluation Logic

Rules are evaluated **top-to-bottom**, first match wins:

```
for each rule in triggers.rules:
  match = true

  if rule.match.tags exists:
    match = match AND (ticket has ANY tag in rule.match.tags)

  if rule.match.priority exists:
    match = match AND (ticket.priority is in rule.match.priority)

  if rule.match.project exists:
    match = match AND (ticket.project is in rule.match.project)

  if rule.match is empty {}:
    match = true  (catch-all)

  if match:
    return rule.action  (auto_start | require_approval | ignore)
```

## Step 4: Process Each Ticket

### If action == "auto_start"
1. Display: `[NLoop Poll] Auto-starting {ticket_id}: {title}`
2. Create feature directory: `.nloop/features/{ticket_id}/`
3. Initialize state.json with `trigger: "poll_auto"`
4. Start the orchestration loop (same as `/nloop-start` but non-interactive)
5. Log event: `poll_auto_start`

### If action == "require_approval"
1. Display:
   ```
   [NLoop Poll] Ticket needs approval: {ticket_id} — {title}
     Priority: {priority}
     Tags: {tags}
     Rule matched: {rule.name}
     -> Run /nloop-start {ticket_id} to begin
   ```
2. Do NOT create any files — wait for manual start

### If action == "ignore"
1. Display: `[NLoop Poll] Ignoring {ticket_id}: {title} (rule: {rule.name})`
2. Do nothing

## Step 5: Summary

After processing all tickets, display:
```
[NLoop Poll] Complete — {timestamp}
  New tickets found: {count}
  Auto-started: {count}
  Awaiting approval: {count}
  Ignored: {count}
  Already in pipeline: {count}
```

## Error Handling

- **YouTrack MCP not available**: Display "YouTrack MCP is not configured. Run /nloop-init --with-youtrack to set it up." and stop.
- **YouTrack API error**: Display the error, don't crash. Will retry on next poll interval.
- **Invalid trigger rules**: Display warning about the invalid rule, use default action (require_approval).

## Notes

- This command is designed to be **non-interactive** when called via `/loop`. It should not ask user questions.
- For auto-started features, the orchestration runs automatically. If it needs human input (escalation), it will pause and wait for `/nloop-resume`.
- The polling interval is configured in `nloop.yaml` and used with the `/loop` skill.
