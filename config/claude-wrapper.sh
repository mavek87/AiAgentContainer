#!/bin/bash
if [ "${AGENT_ASK_PERMISSIONS:-false}" != "true" ]; then
  exec claude-real --dangerously-skip-permissions "$@"
else
  exec claude-real "$@"
fi
