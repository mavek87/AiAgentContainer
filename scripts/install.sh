#!/bin/bash

# ==============================================================================
# AI Agent Container — Installer
# ------------------------------------------------------------------------------
# Creates a symlink 'aic' in ~/.local/bin pointing to ai-agent-container-run.sh.
# After installation, 'aic' is available from any directory.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/ai-agent-container-run.sh"
INSTALL_DIR="$HOME/.local/bin"
LINK="$INSTALL_DIR/aic"

# Ensure the source script exists and is executable
if [ ! -f "$SOURCE" ]; then
    echo "❌ Error: $SOURCE not found."
    exit 1
fi
chmod +x "$SOURCE"

# Create ~/.local/bin if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Create (or replace) the symlink
ln -sf "$SOURCE" "$LINK"
echo "✅ Installed: $LINK → $SOURCE"

# Warn if ~/.local/bin is not in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "⚠️  '$INSTALL_DIR' is not in your PATH."
    echo "   Add this line to your ~/.bashrc or ~/.zshrc:"
    echo ""
    echo '   export PATH="$HOME/.local/bin:$PATH"'
    echo ""
    echo "   Then run: source ~/.bashrc"
fi
