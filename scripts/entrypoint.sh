#!/bin/bash
# ==============================================================================
# Container Entrypoint
# ------------------------------------------------------------------------------
# Configures AI tools based on AGENT_ASK_PERMISSIONS.
# Default (unset or false): autonomous mode — tools skip all permission prompts.
# Set AGENT_ASK_PERMISSIONS=true (via 'aic --ask-permissions') to re-enable
# interactive permission checks.
# ==============================================================================

if [ "${AGENT_ASK_PERMISSIONS:-false}" != "true" ]; then
    # OpenCode: copy the permissive config so all operations are auto-approved.
    # Written fresh on every start so it always reflects AGENT_ASK_PERMISSIONS.
    # Claude Code is handled via the 'claude' wrapper script in PATH.
    mkdir -p "${HOME}/.config/opencode"
    cp /etc/aic/opencode-settings.json "${HOME}/.config/opencode/opencode.json"
fi

exec "$@"
