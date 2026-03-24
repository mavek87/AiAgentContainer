#!/bin/bash

# ==============================================================================
# AI Agent Container Runner
# ------------------------------------------------------------------------------
# This script manages the lifecycle of the AI Agent Docker container.
# It handles authentication, session persistence, and Git worktree integration.
# ==============================================================================

# --- HELPER FUNCTIONS ---

# Returns the absolute path to the directory containing this script.
# Uses readlink -f to resolve symlinks, so it works correctly even when
# called via a symlink (e.g. the 'aic' command in ~/.local/bin).
get_script_dir() {
    echo "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
}

# Validates that a name contains only safe characters for Docker container names
# and Git branch names. Exits with an error if the value is non-empty and invalid.
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

# --- INITIALIZATION ---

SCRIPT_DIR=$(get_script_dir)
# PROJECT_DIR is the root of the AIC repository (one level above scripts/).
# docker-compose.yml and worktrees/ live there, not inside scripts/.
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"

# MY_UID/MY_GID are read by docker-compose to run the container as the host user,
# ensuring that files written to /app are owned by the correct user on the host.
export MY_UID="$(id -u)"
export MY_GID="$(id -g)"

# --- AUTHENTICATION ---

# Inform the user which Claude auth method will be used.
# If no API key is set, the user must run 'claude login' inside the container.
if [ -n "${ANTHROPIC_API_KEY}" ]; then
    echo "🔑 Claude auth: API key"
else
    echo "ℹ️  Claude auth: No API key — Please run 'claude login' inside the container if needed."
fi

# --- ARGUMENT PARSING ---

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

# SESSION_NAME must be exported so docker-compose can use it for the container hostname.
export SESSION_NAME
validate_name "$SESSION_NAME" "session name"

# --- SESSION MODE ---

# Persistent mode keeps the agent's home directory alive between sessions via a
# named Docker volume. Ephemeral mode (default) destroys the home on exit,
# giving a clean slate every time.
if [ "${AGENT_MODE}" == "persistent" ]; then
    SERVICE="agent"
    echo "💾 Session: Persistent (home survives between sessions)"
else
    SERVICE="agent-ephemeral"
    echo "🧹 Session: Ephemeral (home is discarded on exit)"
fi

# --- ONE-SHOT ACTIONS (exit after completion) ---

# --reset: deletes the persistent home volume so the next run starts fresh.
# Refuses to proceed if any container is still using the volume.
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

# --cleanup=<name>: removes the git worktree directory and its tracking branch.
if [ -n "$CLEANUP" ]; then
    WORKTREE_DIR="$PROJECT_DIR/worktrees/$CLEANUP"
    if [ -d "$WORKTREE_DIR" ]; then
        echo "🧹 Removing worktree: $CLEANUP"
        git -C "$PROJECT_DIR" worktree remove "$WORKTREE_DIR" && \
            git -C "$PROJECT_DIR" branch -d "ai/$CLEANUP" && \
            echo "✅ Done"
    else
        echo "⚠️  Worktree not found: $WORKTREE_DIR"
        exit 1
    fi
    exit 0
fi

# --- TARGET SELECTION ---

# Determines which directory to mount as /app inside the container:
#   - no argument or ".": use the current working directory
#   - existing path: use that directory
#   - anything else: treat as a feature name and create/reuse a git worktree
if [ -z "$INPUT" ] || [ "$INPUT" == "." ]; then
    export TARGET_PATH="$(pwd)"
    echo "📂 Target: Current Directory ($TARGET_PATH)"
elif [ -d "$INPUT" ]; then
    export TARGET_PATH="$(realpath "$INPUT")"
    echo "📂 Target: Existing Directory ($TARGET_PATH)"
else
    validate_name "$INPUT" "feature name"

    if ! git -C "$(pwd)" rev-parse --git-dir > /dev/null 2>&1; then
        echo "❌ Error: not in a Git repository. Worktree mode requires a git repo."
        exit 1
    fi

    # The worktree is created under ./worktrees/<name> with branch ai/<name>,
    # keeping it separate from the main working tree.
    WORKTREE_DIR="./worktrees/$INPUT"
    if [ ! -d "$WORKTREE_DIR" ]; then
        echo "🌿 Creating Git Worktree: $INPUT"
        git worktree add -b "ai/$INPUT" "$WORKTREE_DIR" HEAD
    fi
    export TARGET_PATH="$(realpath "$WORKTREE_DIR")"
    echo "🌳 Target: Git Worktree ($TARGET_PATH)"
fi

# Safety guard: TARGET_PATH must always be set before reaching this point.
if [ -z "$TARGET_PATH" ]; then
    echo "❌ Error: TARGET_PATH is not set."
    exit 1
fi

# --- CONTAINER LAUNCH ---

# For ephemeral sessions, generate a short random ID used as both the container
# name and the hostname, so 'docker ps' and the shell prompt are readable.
if [ -z "${SESSION_NAME}" ]; then
    export SESSION_NAME="$(cat /proc/sys/kernel/random/uuid | cut -d- -f1)"
fi

CONTAINER_NAME="ai-agent-container-${SESSION_NAME}"

# Named sessions: if a container with this name is already running, open a new
# shell inside it instead of starting a second instance.
# Ephemeral sessions: the container is removed automatically on exit (--rm).
if docker inspect --format '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q true; then
    echo "🔗 Session '$SESSION_NAME' is already running — opening new shell..."
    docker exec -it "$CONTAINER_NAME" /bin/bash
else
    echo "🏷️  Session: $SESSION_NAME"
    docker compose -f "$COMPOSE_FILE" run --rm --name "$CONTAINER_NAME" "$SERVICE"
fi