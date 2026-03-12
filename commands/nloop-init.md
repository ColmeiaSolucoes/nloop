---
description: Initialize NLoop in the current project. Creates .nloop/ directory with agents, config, workflows, and engine templates.
argument-hint: "[--with-youtrack] [--bitbucket workspace/repo]"
---

# NLoop Init — Project Setup

You are initializing the NLoop multi-agent orchestration system in the current project.

## Step 1: Check Prerequisites

1. Verify this is a git repository: run `git rev-parse --is-inside-work-tree`
   - If not a git repo: warn that worktree-based parallelism won't work, but continue
2. Check if `.nloop/` already exists:
   - If yes: ask user "`.nloop/` already exists. Overwrite config files? (agents and engine will be updated, config will be preserved)"
   - If no: proceed with fresh setup

## Step 2: Find Plugin Source

Find the NLoop plugin's installed location to copy template files:

```bash
# Find the plugin root
PLUGIN_ROOT=$(find ~/.claude/plugins -name "plugin.json" -path "*nloop*" -exec dirname {} \; 2>/dev/null | head -1)
```

If found, read template files from `$PLUGIN_ROOT/project-template/`.

If NOT found (plugin not installed, running from source), check if `project-template/` exists in the current working directory or its parent.

## Step 3: Create Directory Structure

```bash
mkdir -p .nloop/{agents,config,workflows,engine/templates,features}
```

## Step 4: Copy Template Files

Copy all files from the plugin's `project-template/` directory to `.nloop/`:

- `project-template/agents/*.md` → `.nloop/agents/`
- `project-template/config/nloop.yaml` → `.nloop/config/nloop.yaml` (only if not exists)
- `project-template/config/triggers.yaml` → `.nloop/config/triggers.yaml` (only if not exists)
- `project-template/workflows/default.yaml` → `.nloop/workflows/default.yaml` (only if not exists)
- `project-template/engine/state-schema.json` → `.nloop/engine/state-schema.json`
- `project-template/engine/templates/*` → `.nloop/engine/templates/`
- `project-template/.gitignore` → `.nloop/.gitignore`

**Important**: Config files (nloop.yaml, triggers.yaml, default.yaml) should NOT be overwritten if they already exist — the user may have customized them. Agent and engine files should always be updated to the latest version.

## Step 5: Configure Bitbucket (Interactive)

If `$ARGUMENTS` contains `--bitbucket`:
- Parse workspace/repo from arguments
- Update `.nloop/config/nloop.yaml` with the Bitbucket settings

Otherwise, ask the user:
1. "Do you use Bitbucket for PRs? If yes, what's your workspace/repo slug?" (e.g., `myteam/myrepo`)
2. If provided, update `.nloop/config/nloop.yaml`:
   - Set `bitbucket.workspace`
   - Set `bitbucket.repo`
   - Set `bitbucket.base_url` to `https://bitbucket.org`

## Step 6: Setup YouTrack MCP (Optional)

If `$ARGUMENTS` contains `--with-youtrack`:

1. Check if Node.js is available
2. Copy MCP source from plugin: `$PLUGIN_ROOT/mcp/youtrack/` → `.nloop/mcp/youtrack/`
3. Run `cd .nloop/mcp/youtrack && npm install && npm run build`
4. Create/update `.claude/settings.json` in the project:
   ```json
   {
     "mcpServers": {
       "youtrack": {
         "command": "node",
         "args": [".nloop/mcp/youtrack/dist/index.js"],
         "env": {
           "YOUTRACK_TOKEN": "${YOUTRACK_TOKEN}",
           "YOUTRACK_BASE_URL": "${YOUTRACK_BASE_URL}"
         }
       }
     }
   }
   ```

Otherwise, inform the user:
```
YouTrack MCP not configured. To add it later, run:
/nloop-init --with-youtrack
```

## Step 7: Update .gitignore

If this is a git repo, ensure the project's `.gitignore` contains:
```
# NLoop runtime data
.nloop/features/
.nloop/mcp/youtrack/node_modules/
.nloop/mcp/youtrack/dist/
```

Only add these lines if they don't already exist.

## Step 8: Create .env.example

Create `.nloop/.env.example` if it doesn't exist:
```
# NLoop Environment Variables
BITBUCKET_TOKEN=your-bitbucket-app-password
YOUTRACK_TOKEN=your-youtrack-permanent-token
YOUTRACK_BASE_URL=https://your-team.youtrack.cloud
```

## Step 9: Display Summary

```
NLoop initialized successfully!

  Project:   {current directory}
  Config:    .nloop/config/nloop.yaml
  Workflow:  .nloop/workflows/default.yaml
  Agents:    .nloop/agents/ (8 agents)

  Quick Start:
    /nloop-start TICKET-ID     Start a feature
    /nloop-resume TICKET-ID    Resume a paused feature
    /nloop-status              View dashboard
    /nloop-poll                Check YouTrack for new tickets

  Customize:
    Edit agents:    .nloop/agents/*.md
    Edit workflow:  .nloop/workflows/default.yaml
    Edit config:    .nloop/config/nloop.yaml
    Edit triggers:  .nloop/config/triggers.yaml
```
