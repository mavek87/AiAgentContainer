#!/bin/bash

# ==============================================================================
# AI Agent Container — Uninstaller
# ------------------------------------------------------------------------------
# Removes the 'aic' command and, if installed via curl (remote mode),
# also removes the cloned repository from ~/.local/share/aic.
#
# Does NOT remove the Docker image or persistent volumes unless --purge is used.
#
# Usage:
#   ./scripts/uninstall.sh          # remove 'aic' command only
#   ./scripts/uninstall.sh --purge  # also remove Docker image and volumes
# ==============================================================================

set -e

BIN_LINK="$HOME/.local/bin/aic"
REMOTE_INSTALL_DIR="$HOME/.local/share/aic"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}✅ $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠️  $*${RESET}"; }

PURGE=false
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=true ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║      AI Agent Container — Uninstaller    ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${RESET}"

# --- REMOVE REMOTE CLONE (if present, ask first) ---
REMOVE_CLONE=false
if [ -d "$REMOTE_INSTALL_DIR/.git" ]; then
    echo "Remote installation found at: $REMOTE_INSTALL_DIR"
    read -r -p "Remove it? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        REMOVE_CLONE=true
    else
        warn "Skipped removal of $REMOTE_INSTALL_DIR"
    fi
fi

# --- REMOVE 'aic' SYMLINK ---
if [ -L "$BIN_LINK" ]; then
    rm "$BIN_LINK"
    ok "Removed: $BIN_LINK"
else
    warn "'aic' is not installed at $BIN_LINK — skipping."
fi

# --- REMOVE REMOTE CLONE ---
if [ "$REMOVE_CLONE" = true ]; then
    rm -rf "$REMOTE_INSTALL_DIR"
    ok "Removed: $REMOTE_INSTALL_DIR"
fi

# --- PURGE DOCKER RESOURCES ---
if [ "$PURGE" = true ]; then
    echo ""
    echo "▶ Purging Docker resources..."

    if docker image inspect ai-agent-container &>/dev/null; then
        docker rmi ai-agent-container
        ok "Docker image removed: ai-agent-container"
    else
        warn "Docker image 'ai-agent-container' not found."
    fi

    VOLUMES=$(docker volume ls -q | grep ai_home_volume || true)
    if [ -n "$VOLUMES" ]; then
        echo "$VOLUMES" | xargs docker volume rm
        ok "Persistent volume(s) removed."
    else
        warn "No persistent volumes found."
    fi
else
    echo ""
    echo "The Docker image and persistent volumes are NOT removed."
    echo "To remove them as well, run:"
    echo "  aic --uninstall --purge"
fi

echo ""
ok "Uninstallation complete."
