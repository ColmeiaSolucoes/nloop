#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
#  NLoop Installer — Multi-Agent Orchestration for Claude Code
# ═══════════════════════════════════════════════════════════════

NLOOP_SOURCE="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"
VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}   ${BOLD}NLoop Installer${NC} v${VERSION}                        ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}   Multi-Agent Orchestration for Claude Code     ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
}

log_info()    { echo -e "  ${BLUE}ℹ${NC}  $1"; }
log_success() { echo -e "  ${GREEN}✓${NC}  $1"; }
log_warn()    { echo -e "  ${YELLOW}⚠${NC}  $1"; }
log_error()   { echo -e "  ${RED}✗${NC}  $1"; }
log_step()    { echo -e "\n${BOLD}[$1/$TOTAL_STEPS] $2${NC}"; }

ask_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  local yn
  if [[ "$default" == "y" ]]; then
    read -r -p "  → $prompt [Y/n]: " yn
    yn="${yn:-y}"
  else
    read -r -p "  → $prompt [y/N]: " yn
    yn="${yn:-n}"
  fi
  [[ "$yn" =~ ^[Yy] ]]
}

ask_input() {
  local prompt="$1"
  local default="${2:-}"
  local value
  if [[ -n "$default" ]]; then
    read -r -p "  → $prompt [$default]: " value
    echo "${value:-$default}"
  else
    read -r -p "  → $prompt: " value
    echo "$value"
  fi
}

# ─── Detect target project ───────────────────────────────────

detect_target() {
  if [[ -n "${1:-}" ]]; then
    TARGET_DIR="$(cd "$1" 2>/dev/null && pwd)" || {
      log_error "Directory not found: $1"
      exit 1
    }
  else
    TARGET_DIR="$(pwd)"
  fi

  # Don't install into the nloop source itself
  if [[ "$TARGET_DIR" == "$NLOOP_SOURCE" || "$TARGET_DIR" == "$(dirname "$NLOOP_SOURCE")" ]]; then
    log_error "Cannot install NLoop into its own source directory."
    log_info "Run this from your project directory: cd /path/to/your/project && ${NLOOP_SOURCE}/install.sh"
    exit 1
  fi
}

# ─── Step counters ────────────────────────────────────────────

TOTAL_STEPS=6
CURRENT_STEP=0

# ═══════════════════════════════════════════════════════════════
#  STEP 1: Validate environment
# ═══════════════════════════════════════════════════════════════

step_validate() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  log_step "$CURRENT_STEP" "Validating environment"

  # Check Claude Code home
  if [[ ! -d "$CLAUDE_HOME" ]]; then
    log_error "Claude Code home not found at $CLAUDE_HOME"
    log_info "Make sure Claude Code is installed and has been run at least once."
    exit 1
  fi
  log_success "Claude Code home: $CLAUDE_HOME"

  # Check target directory
  log_info "Target project: ${BOLD}$TARGET_DIR${NC}"
  if [[ ! -d "$TARGET_DIR" ]]; then
    log_error "Target directory does not exist: $TARGET_DIR"
    exit 1
  fi
  log_success "Target directory exists"

  # Check if git repo (optional but recommended)
  if git -C "$TARGET_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    log_success "Git repository detected"
    IS_GIT_REPO=true
  else
    log_warn "Not a git repository — worktree-based parallelism won't work"
    IS_GIT_REPO=false
  fi

  # Check node/npm for MCP
  if command -v node &>/dev/null; then
    NODE_VERSION=$(node -v)
    log_success "Node.js: $NODE_VERSION"
    HAS_NODE=true
  else
    log_warn "Node.js not found — YouTrack MCP won't be installed"
    HAS_NODE=false
  fi
}

# ═══════════════════════════════════════════════════════════════
#  STEP 2: Install global skills
# ═══════════════════════════════════════════════════════════════

step_install_skills() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  log_step "$CURRENT_STEP" "Installing global skills"

  local skills_dir="$CLAUDE_HOME/skills"
  mkdir -p "$skills_dir"

  local skills=(nloop-start nloop-resume nloop-poll nloop-status)
  for skill in "${skills[@]}"; do
    local src="$NLOOP_SOURCE/skills/$skill"
    local dst="$skills_dir/$skill"

    if [[ -d "$dst" ]]; then
      if ask_yes_no "Skill /$skill already exists. Overwrite?" "y"; then
        rm -rf "$dst"
      else
        log_warn "Skipped /$skill"
        continue
      fi
    fi

    mkdir -p "$dst"
    cp "$src/SKILL.md" "$dst/SKILL.md"
    log_success "Installed /$skill"
  done
}

# ═══════════════════════════════════════════════════════════════
#  STEP 3: Install project files
# ═══════════════════════════════════════════════════════════════

step_install_project() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  log_step "$CURRENT_STEP" "Installing NLoop into project"

  local nloop_dir="$TARGET_DIR/.nloop"

  if [[ -d "$nloop_dir" ]]; then
    if ask_yes_no ".nloop directory already exists in project. Overwrite?" "n"; then
      rm -rf "$nloop_dir"
    else
      log_warn "Keeping existing .nloop/ directory. Only missing files will be added."
    fi
  fi

  # Create directory structure
  mkdir -p "$nloop_dir"/{agents,workflows,config,engine/templates,features}

  # Copy agents
  for agent in "$NLOOP_SOURCE"/agents/*.md; do
    local name=$(basename "$agent")
    local dst="$nloop_dir/agents/$name"
    if [[ ! -f "$dst" ]]; then
      cp "$agent" "$dst"
      log_success "Agent: $name"
    else
      log_info "Agent already exists: $name (skipped)"
    fi
  done

  # Copy workflow
  if [[ ! -f "$nloop_dir/workflows/default.yaml" ]]; then
    cp "$NLOOP_SOURCE/workflows/default.yaml" "$nloop_dir/workflows/default.yaml"
    log_success "Workflow: default.yaml"
  else
    log_info "Workflow already exists (skipped)"
  fi

  # Copy config (only if not exists — don't overwrite user config)
  for cfg in nloop.yaml triggers.yaml; do
    if [[ ! -f "$nloop_dir/config/$cfg" ]]; then
      cp "$NLOOP_SOURCE/config/$cfg" "$nloop_dir/config/$cfg"
      log_success "Config: $cfg"
    else
      log_info "Config already exists: $cfg (skipped)"
    fi
  done

  # Copy engine files
  if [[ ! -f "$nloop_dir/engine/state-schema.json" ]]; then
    cp "$NLOOP_SOURCE/engine/state-schema.json" "$nloop_dir/engine/state-schema.json"
    log_success "Engine: state-schema.json"
  fi

  for tpl in "$NLOOP_SOURCE"/engine/templates/*; do
    local name=$(basename "$tpl")
    local dst="$nloop_dir/engine/templates/$name"
    if [[ ! -f "$dst" ]]; then
      cp "$tpl" "$dst"
      log_success "Template: $name"
    fi
  done

  # Copy .gitignore and README
  if [[ ! -f "$nloop_dir/.gitignore" ]]; then
    cp "$NLOOP_SOURCE/.gitignore" "$nloop_dir/.gitignore"
    log_success ".gitignore"
  fi
  if [[ ! -f "$nloop_dir/README.md" ]]; then
    cp "$NLOOP_SOURCE/README.md" "$nloop_dir/README.md"
    log_success "README.md"
  fi
}

# ═══════════════════════════════════════════════════════════════
#  STEP 4: Configure project settings
# ═══════════════════════════════════════════════════════════════

step_configure() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  log_step "$CURRENT_STEP" "Configuring project settings"

  local config_file="$TARGET_DIR/.nloop/config/nloop.yaml"

  if ask_yes_no "Configure Bitbucket integration now?" "y"; then
    local bb_workspace=$(ask_input "Bitbucket workspace (slug)")
    local bb_repo=$(ask_input "Bitbucket repository (slug)")
    local bb_base=$(ask_input "Bitbucket base URL" "https://bitbucket.org")

    if [[ -n "$bb_workspace" && -n "$bb_repo" ]]; then
      # Use sed to update config
      sed -i.bak "s|workspace: \"\"|workspace: \"$bb_workspace\"|" "$config_file"
      sed -i.bak "s|repo: \"\"|repo: \"$bb_repo\"|" "$config_file"
      sed -i.bak "s|base_url: \"\"|base_url: \"$bb_base\"|" "$config_file"
      rm -f "$config_file.bak"
      log_success "Bitbucket configured: $bb_workspace/$bb_repo"
    fi

    if ask_yes_no "Add default reviewers?" "n"; then
      local reviewers=$(ask_input "Reviewer usernames (comma-separated)")
      if [[ -n "$reviewers" ]]; then
        # Convert comma-separated to YAML array
        local yaml_reviewers=$(echo "$reviewers" | sed 's/,/", "/g')
        sed -i.bak "s|default_reviewers: \[\]|default_reviewers: [\"$yaml_reviewers\"]|" "$config_file"
        rm -f "$config_file.bak"
        log_success "Reviewers added: $reviewers"
      fi
    fi
  else
    log_info "Skipped — edit .nloop/config/nloop.yaml later"
  fi

  # Environment variables
  echo ""
  log_info "Environment variables needed:"
  echo ""
  echo -e "    ${BOLD}# Add to your shell profile (~/.zshrc or ~/.bashrc):${NC}"
  echo -e "    export BITBUCKET_TOKEN=\"your-bitbucket-app-password\""
  echo -e "    export YOUTRACK_TOKEN=\"your-youtrack-token\""
  echo -e "    export YOUTRACK_BASE_URL=\"https://your-team.youtrack.cloud\""
  echo ""

  # Create .env.example in project
  local env_example="$TARGET_DIR/.nloop/.env.example"
  if [[ ! -f "$env_example" ]]; then
    cat > "$env_example" << 'ENVEOF'
# NLoop Environment Variables
# Copy to your shell profile or use with direnv

# Bitbucket (for PR creation)
BITBUCKET_TOKEN=your-bitbucket-app-password

# YouTrack (for ticket integration)
YOUTRACK_TOKEN=your-youtrack-permanent-token
YOUTRACK_BASE_URL=https://your-team.youtrack.cloud
ENVEOF
    log_success "Created .env.example"
  fi
}

# ═══════════════════════════════════════════════════════════════
#  STEP 5: Install YouTrack MCP
# ═══════════════════════════════════════════════════════════════

step_install_mcp() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  log_step "$CURRENT_STEP" "Setting up YouTrack MCP"

  if [[ "$HAS_NODE" != "true" ]]; then
    log_warn "Skipping MCP — Node.js not available"
    log_info "Install Node.js and re-run, or set up manually later"
    return
  fi

  if ! ask_yes_no "Install YouTrack MCP server?" "y"; then
    log_info "Skipped — install later with: cd .nloop/mcp/youtrack && npm install && npm run build"
    return
  fi

  local mcp_dir="$TARGET_DIR/.nloop/mcp/youtrack"
  mkdir -p "$mcp_dir/src"

  # Copy MCP files
  cp "$NLOOP_SOURCE/mcp/youtrack/package.json" "$mcp_dir/package.json"
  cp "$NLOOP_SOURCE/mcp/youtrack/tsconfig.json" "$mcp_dir/tsconfig.json"
  cp "$NLOOP_SOURCE/mcp/youtrack/src/index.ts" "$mcp_dir/src/index.ts"
  log_success "MCP source files copied"

  # Install dependencies
  log_info "Installing dependencies..."
  (cd "$mcp_dir" && npm install --silent 2>&1) && log_success "Dependencies installed" || {
    log_warn "npm install failed — run manually: cd $mcp_dir && npm install"
  }

  # Build
  log_info "Building MCP server..."
  (cd "$mcp_dir" && npm run build --silent 2>&1) && log_success "MCP server built" || {
    log_warn "Build failed — run manually: cd $mcp_dir && npm run build"
  }

  # Register MCP in Claude Code settings
  local claude_settings="$CLAUDE_HOME/settings.json"
  local mcp_dist_path="$mcp_dir/dist/index.js"

  echo ""
  log_info "To register the MCP in Claude Code, add this to your MCP settings:"
  echo ""
  echo -e "    ${BOLD}\"youtrack\": {${NC}"
  echo -e "    ${BOLD}  \"command\": \"node\",${NC}"
  echo -e "    ${BOLD}  \"args\": [\"$mcp_dist_path\"],${NC}"
  echo -e "    ${BOLD}  \"env\": {${NC}"
  echo -e "    ${BOLD}    \"YOUTRACK_TOKEN\": \"your-token\",${NC}"
  echo -e "    ${BOLD}    \"YOUTRACK_BASE_URL\": \"https://your-team.youtrack.cloud\"${NC}"
  echo -e "    ${BOLD}  }${NC}"
  echo -e "    ${BOLD}}${NC}"
  echo ""

  if ask_yes_no "Auto-register MCP in Claude Code project settings?" "y"; then
    local project_settings_dir="$TARGET_DIR/.claude"
    mkdir -p "$project_settings_dir"

    local mcp_config_file="$project_settings_dir/settings.json"

    if [[ -f "$mcp_config_file" ]]; then
      # Check if mcpServers already exists
      if grep -q "mcpServers" "$mcp_config_file" 2>/dev/null; then
        log_warn "settings.json already has mcpServers — add YouTrack manually"
      else
        # Simple approach: create a new file with mcpServers
        log_warn "Existing settings.json found — add YouTrack MCP manually"
      fi
    else
      cat > "$mcp_config_file" << MCPEOF
{
  "mcpServers": {
    "youtrack": {
      "command": "node",
      "args": ["$mcp_dist_path"],
      "env": {
        "YOUTRACK_TOKEN": "\${YOUTRACK_TOKEN}",
        "YOUTRACK_BASE_URL": "\${YOUTRACK_BASE_URL}"
      }
    }
  }
}
MCPEOF
      log_success "MCP registered in .claude/settings.json"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════
#  STEP 6: Finalize
# ═══════════════════════════════════════════════════════════════

step_finalize() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  log_step "$CURRENT_STEP" "Finalizing installation"

  # Add .nloop/features/ to .gitignore if git repo
  if [[ "$IS_GIT_REPO" == "true" ]]; then
    local gitignore="$TARGET_DIR/.gitignore"
    if [[ -f "$gitignore" ]]; then
      if ! grep -q ".nloop/features/" "$gitignore" 2>/dev/null; then
        echo "" >> "$gitignore"
        echo "# NLoop runtime data" >> "$gitignore"
        echo ".nloop/features/" >> "$gitignore"
        echo ".nloop/mcp/youtrack/node_modules/" >> "$gitignore"
        echo ".nloop/mcp/youtrack/dist/" >> "$gitignore"
        log_success "Updated .gitignore"
      fi
    else
      cat > "$gitignore" << 'GIEOF'
# NLoop runtime data
.nloop/features/
.nloop/mcp/youtrack/node_modules/
.nloop/mcp/youtrack/dist/
GIEOF
      log_success "Created .gitignore"
    fi
  fi

  # Print summary
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  NLoop installed successfully!${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  ${BOLD}Project:${NC}  $TARGET_DIR"
  echo -e "  ${BOLD}NLoop:${NC}    $TARGET_DIR/.nloop/"
  echo -e "  ${BOLD}Skills:${NC}   $CLAUDE_HOME/skills/nloop-*/"
  echo ""
  echo -e "  ${BOLD}Quick Start:${NC}"
  echo -e "    1. Set environment variables (see .env.example)"
  echo -e "    2. Open Claude Code in your project"
  echo -e "    3. Run: ${CYAN}/nloop-start TICKET-ID \"Description\"${NC}"
  echo ""
  echo -e "  ${BOLD}Commands:${NC}"
  echo -e "    ${CYAN}/nloop-start TICKET-ID${NC}   Start a feature"
  echo -e "    ${CYAN}/nloop-resume TICKET-ID${NC}  Resume a paused feature"
  echo -e "    ${CYAN}/nloop-status${NC}            View dashboard"
  echo -e "    ${CYAN}/nloop-poll${NC}              Check YouTrack for new tickets"
  echo -e "    ${CYAN}/loop 30m /nloop-poll${NC}    Auto-poll every 30 min"
  echo ""
  echo -e "  ${BOLD}Customize:${NC}"
  echo -e "    Agents:    ${TARGET_DIR}/.nloop/agents/*.md"
  echo -e "    Workflow:  ${TARGET_DIR}/.nloop/workflows/default.yaml"
  echo -e "    Config:    ${TARGET_DIR}/.nloop/config/nloop.yaml"
  echo -e "    Triggers:  ${TARGET_DIR}/.nloop/config/triggers.yaml"
  echo ""
}

# ═══════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════

main() {
  print_banner
  detect_target "${1:-}"

  step_validate
  step_install_skills
  step_install_project
  step_configure
  step_install_mcp
  step_finalize
}

# ─── Uninstall mode ───────────────────────────────────────────

uninstall() {
  print_banner
  detect_target "${2:-}"

  echo -e "${YELLOW}  Uninstalling NLoop from:${NC}"
  echo -e "  Project: $TARGET_DIR"
  echo -e "  Global:  $CLAUDE_HOME/skills/nloop-*"
  echo ""

  if ! ask_yes_no "Are you sure?" "n"; then
    echo "  Cancelled."
    exit 0
  fi

  # Remove project files
  if [[ -d "$TARGET_DIR/.nloop" ]]; then
    rm -rf "$TARGET_DIR/.nloop"
    log_success "Removed $TARGET_DIR/.nloop/"
  fi

  # Remove global skills
  for skill in nloop-start nloop-resume nloop-poll nloop-status; do
    if [[ -d "$CLAUDE_HOME/skills/$skill" ]]; then
      rm -rf "$CLAUDE_HOME/skills/$skill"
      log_success "Removed skill /$skill"
    fi
  done

  # Remove from .gitignore
  if [[ -f "$TARGET_DIR/.gitignore" ]]; then
    sed -i.bak '/\.nloop/d' "$TARGET_DIR/.gitignore"
    rm -f "$TARGET_DIR/.gitignore.bak"
    log_success "Cleaned .gitignore"
  fi

  echo ""
  log_success "NLoop uninstalled."
  log_info "Environment variables (BITBUCKET_TOKEN, YOUTRACK_*) were not removed — clean up manually if needed."
}

# ─── Entry point ──────────────────────────────────────────────

case "${1:-}" in
  --uninstall|-u)
    uninstall "$@"
    ;;
  --help|-h)
    print_banner
    echo "Usage:"
    echo "  ./install.sh [TARGET_DIR]        Install NLoop into a project"
    echo "  ./install.sh --uninstall [DIR]   Remove NLoop from a project"
    echo "  ./install.sh --help              Show this help"
    echo ""
    echo "If TARGET_DIR is omitted, the current directory is used."
    ;;
  *)
    main "$@"
    ;;
esac
