#!/bin/bash

# ==============================================================================
# AI Agent Container — Installer
# ------------------------------------------------------------------------------
# Works in two modes:
#
#   REMOTE (curl | bash):
#     curl -fsSL https://raw.githubusercontent.com/mavek87/AiAgentContainer/main/scripts/install.sh | bash
#     → Clones the repo to ~/.local/share/aic, builds the Docker image, installs 'aic'.
#
#   LOCAL (already cloned):
#     ./scripts/install.sh
#     → Builds the Docker image in-place, installs 'aic' pointing to this repo.
# ==============================================================================

set -e

REPO_URL="https://github.com/mavek87/AiAgentContainer.git"
INSTALL_DIR="$HOME/.local/share/aic"
BIN_DIR="$HOME/.local/bin"
BIN_LINK="$BIN_DIR/aic"

# --- COLORS ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}✅ $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠️  $*${RESET}"; }
die()  { echo -e "${RED}❌ $*${RESET}" >&2; exit 1; }
step() { echo -e "\n${BOLD}▶ $*${RESET}"; }

# --- DETECT MODE ---
# If BASH_SOURCE[0] resolves to a path inside a git repo, we're in local mode.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]:-/dev/stdin}")")" 2>/dev/null && pwd || true)"
if [ -f "$SCRIPT_DIR/ai-agent-container-run.sh" ]; then
    MODE="local"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
else
    MODE="remote"
    PROJECT_DIR="$INSTALL_DIR"
fi

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║       AI Agent Container — Installer     ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${RESET}"
echo "Mode: $MODE"

# --- CHECK PREREQUISITES ---
step "Checking prerequisites..."

check_cmd() {
    if ! command -v "$1" &>/dev/null; then
        die "'$1' is required but not installed. $2"
    fi
    ok "$1 found: $(command -v "$1")"
}

check_cmd git  "Install it from https://git-scm.com"
check_cmd docker "Install it from https://docs.docker.com/get-docker/"

if ! docker compose version &>/dev/null; then
    die "'docker compose' (v2) is required. Install the Docker Compose plugin: https://docs.docker.com/compose/install/"
fi
ok "docker compose found"

if ! docker info &>/dev/null; then
    die "Docker daemon is not running. Start it and retry."
fi
ok "Docker daemon is running"

# --- CLONE OR UPDATE REPO (remote mode only) ---
if [ "$MODE" = "remote" ]; then
    step "Setting up repository..."
    if [ -d "$INSTALL_DIR/.git" ]; then
        warn "Existing installation found at $INSTALL_DIR — updating..."
        git -C "$INSTALL_DIR" pull --ff-only
        ok "Repository updated"
    else
        echo "Cloning into $INSTALL_DIR ..."
        mkdir -p "$(dirname "$INSTALL_DIR")"
        git clone "$REPO_URL" "$INSTALL_DIR"
        ok "Repository cloned"
    fi
fi

# --- BUILD DOCKER IMAGE ---
step "Building Docker image (this may take a few minutes on first run)..."
docker compose -f "$PROJECT_DIR/docker-compose.yml" build
ok "Docker image built"

# --- INSTALL 'aic' COMMAND ---
step "Installing 'aic' command..."
mkdir -p "$BIN_DIR"
chmod +x "$PROJECT_DIR/scripts/ai-agent-container-run.sh"
ln -sf "$PROJECT_DIR/scripts/ai-agent-container-run.sh" "$BIN_LINK"
ok "Installed: $BIN_LINK → $PROJECT_DIR/scripts/ai-agent-container-run.sh"

# --- PATH CHECK ---
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    warn "'$BIN_DIR' is not in your PATH."

    SHELL_RC=""
    case "$SHELL" in
        */zsh)  SHELL_RC="$HOME/.zshrc" ;;
        */bash) SHELL_RC="$HOME/.bashrc" ;;
    esac

    if [ -n "$SHELL_RC" ]; then
        if ! grep -qF 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_RC" 2>/dev/null; then
            echo '' >> "$SHELL_RC"
            echo '# Added by AiAgentContainer installer' >> "$SHELL_RC"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
            ok "PATH updated in $SHELL_RC"
            echo "   Run: source $SHELL_RC"
        else
            warn "PATH entry already present in $SHELL_RC (but not active in this shell)."
            echo "   Run: source $SHELL_RC"
        fi
    else
        echo "   Add this line to your shell config:"
        echo '   export PATH="$HOME/.local/bin:$PATH"'
    fi
fi

# --- DONE ---
echo ""
echo -e "${GREEN}${BOLD}Installation complete!${RESET}"
echo ""
echo "Usage:"
echo "  aic                        # start in current directory (ephemeral)"
echo "  aic --help                 # show all options"
echo "  AGENT_MODE=persistent aic  # persistent session"
echo ""
echo "To update later:"
if [ "$MODE" = "remote" ]; then
    echo "  aic --update"
else
    echo "  git pull && ./scripts/install.sh"
fi
