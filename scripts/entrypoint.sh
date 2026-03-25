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
    # OpenCode: write a config that grants permission for all operations.
    # This file is written fresh on every container start so it always reflects
    # the current value of AGENT_ASK_PERMISSIONS.
    mkdir -p "${HOME}/.config/opencode"
    cat > "${HOME}/.config/opencode/opencode.json" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "*": { "*": "allow" }
  }
}
EOF
    # Claude Code is handled via the 'claude' wrapper script in PATH,
    # which passes --dangerously-skip-permissions when this variable is unset.
fi

exec "$@"
