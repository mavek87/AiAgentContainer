#!/bin/bash

# ==============================================================================
# AI Agent Container Runner
# ------------------------------------------------------------------------------
# This script manages the lifecycle of the AI Agent Docker container.
# It handles authentication, session persistence, and Git worktree integration.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

# Export UID/GID to ensure file permissions match the host user inside the container
export MY_UID="$(id -u)"
export MY_GID="$(id -g)"

# --- HELPER FUNCTIONS ---

validate_name() {
    local value="$1" field="$2"
    if [ -n "$value" ] && [[ ! "$value" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        echo "❌ Error: $field '$value' is invalid. Use only letters, numbers, hyphens, underscores."
        exit 1
    fi
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [TARGET]

Options:
  -h, --help           Show this help message.
  -n, --name <name>    Assign a name to the session (re-attaches if already running).
  --reset              Remove the persistent volume (requires AGENT_MODE=persistent).
  --cleanup=<name>     Remove the specified git worktree and its branch.

Target (optional):
  (empty) or .         Use the current directory (default).
  <path>               Use an existing directory.
  <feature_name>       Create or reuse a Git worktree for the specified feature.

Environment variables:
  ANTHROPIC_API_KEY    API key for Claude authentication.
  AGENT_MODE           Set to 'persistent' to keep the home directory between sessions.
EOF
    exit 0
}

# ------------------------

# Claude Authentication
if [ -n "${ANTHROPIC_API_KEY}" ]; then
    echo "🔑 Claude auth: API key"
else
    echo "ℹ️  Claude auth: no API key — use AGENT_MODE=persistent and run 'claude login' on first start"
fi

# Argument parsing
INPUT=""
RESET=false
CLEANUP=""
SESSION_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -n|--name)
            SESSION_NAME="$2"
            shift 2
            ;;
        --reset)
            RESET=true
            shift
            ;;
        --cleanup=*)
            CLEANUP="${1#--cleanup=}"
            shift
            ;;
        -*)
            echo "❌ Error: unrecognized option '$1'. Use --help to see available options."
            exit 1
            ;;
        *)
            INPUT="$1"
            shift
            ;;
    esac
done

export SESSION_NAME
validate_name "$SESSION_NAME" "session name"

# Mode selection
if [ "${AGENT_MODE}" == "persistent" ]; then
    SERVICE="agent"
    echo "💾 Session: Persistent (home survives between sessions)"
else
    SERVICE="agent-ephemeral"
    echo "🧹 Session: Ephemeral (home is discarded on exit)"
fi

# Logic for --reset
if [ "$RESET" = true ]; then
    if [ "$SERVICE" == "agent" ]; then
        PROJECT=$(docker compose -f "$COMPOSE_FILE" config --project-name 2>/dev/null)
        VOLUME_NAME="${PROJECT}_ai_home_volume"

        CONTAINERS=$(docker ps -q --filter "volume=${VOLUME_NAME}")
        if [ -n "$CONTAINERS" ]; then
            echo "❌ Volume '${VOLUME_NAME}' is in use by running containers. Stop them first:"
            docker ps --filter "volume=${VOLUME_NAME}" --format "  {{.Names}}"
            exit 1
        fi

        echo "🗑️  Removing persistent home volume: $VOLUME_NAME"
        docker volume rm "$VOLUME_NAME" 2>/dev/null && echo "✅ Done" || echo "⚠️  Volume not found (already removed?)"
    else
        echo "⚠️  --reset is only useful with AGENT_MODE=persistent"
    fi
    exit 0
fi

# Logic for --cleanup=<name>
if [ -n "$CLEANUP" ]; then
    WORKTREE_DIR="$SCRIPT_DIR/worktrees/$CLEANUP"
    if [ -d "$WORKTREE_DIR" ]; then
        echo "🧹 Removing worktree: $CLEANUP"
        git -C "$SCRIPT_DIR" worktree remove "$WORKTREE_DIR" && \
            git -C "$SCRIPT_DIR" branch -d "ai/$CLEANUP" && \
            echo "✅ Done"
    else
        echo "⚠️  Worktree not found: $WORKTREE_DIR"
        exit 1
    fi
    exit 0
fi

# Target selection logic
if [ -z "$INPUT" ] || [ "$INPUT" == "." ]; then
    export TARGET_PATH="$(pwd)"
    echo "📂 Target: Current Directory ($TARGET_PATH)"
elif [ -d "$INPUT" ]; then
    export TARGET_PATH="$(realpath "$INPUT")"
    echo "📂 Target: Existing Directory ($TARGET_PATH)"
else
    # Validate feature name
    validate_name "$INPUT" "feature name"

    # Treat it as a Git worktree feature name
    if ! git -C "$(pwd)" rev-parse --git-dir > /dev/null 2>&1; then
        echo "❌ Error: not in a Git repository. Worktree mode requires a git repo."
        exit 1
    fi

    WORKTREE_DIR="./worktrees/$INPUT"
    if [ ! -d "$WORKTREE_DIR" ]; then
        echo "🌿 Creating Git Worktree: $INPUT"
        git worktree add -b "ai/$INPUT" "$WORKTREE_DIR" HEAD
    fi
    export TARGET_PATH="$(realpath "$WORKTREE_DIR")"
    echo "🌳 Target: Git Worktree ($TARGET_PATH)"
fi

# Explicit guard
if [ -z "$TARGET_PATH" ]; then
    echo "❌ Error: TARGET_PATH is not set."
    exit 1
fi

# Container Launch Logic
if [ -n "${SESSION_NAME}" ]; then
    CONTAINER_NAME="ai-agent-container-${SESSION_NAME}"
    if docker inspect --format '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q true; then
        echo "🔗 Session '$SESSION_NAME' is already running — opening new shell..."
        docker exec -it "$CONTAINER_NAME" /bin/bash
    else
        echo "🏷️  Session: $SESSION_NAME"
        docker compose -f "$COMPOSE_FILE" run --rm --name "$CONTAINER_NAME" "$SERVICE"
    fi
else
    docker compose -f "$COMPOSE_FILE" run --rm "$SERVICE"
fi