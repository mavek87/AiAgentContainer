#!/bin/bash

# ==============================================================================
# AI Agent Container — Uninstaller
# ------------------------------------------------------------------------------
# Removes the 'aic' symlink from ~/.local/bin.
# Does not remove the Docker image or persistent volumes.
# ==============================================================================

LINK="$HOME/.local/bin/aic"

if [ ! -L "$LINK" ]; then
    echo "⚠️  'aic' is not installed at $LINK."
    exit 0
fi

rm "$LINK"
echo "✅ Removed: $LINK"
echo "   The Docker image and persistent volumes are not affected."
echo "   To remove them: docker rmi ai-agent-container && docker volume rm \$(docker volume ls -q | grep ai_home_volume)"
