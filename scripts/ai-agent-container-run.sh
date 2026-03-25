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
  -h, --help             Show this help message.
  -v, --version          Show the current version.
  -n, --name <name>      Assign a name to the session (re-attaches if already running).
  --ask-permissions      Enable interactive permission prompts (default: autonomous/no prompts).
  --reset                Remove the persistent volume (requires AGENT_MODE=persistent).
  --cleanup=<name>       Remove the specified git worktree and its branch.
  --branch-push          Allow git push only to the current branch (mounts SSH keys).
  -y, --yes              Skip confirmation prompts.
  -u, --update           Pull latest changes and rebuild the Docker image.
  -d, --uninstall        Remove the 'aic' command (add --purge to also remove image and volumes).

Target (optional):
  (empty) or .         Use the current directory (default).
  <path>               Use an existing directory.
  <feature_name>       Create or reuse a Git worktree for the specified feature.

Environment variables:
  ANTHROPIC_API_KEY    API key for Claude authentication.
  AGENT_MODE           Set to 'persistent' to keep the home directory between sessions.
  AGENT_ASK_PERMISSIONS  Set to 'true' to enable permission prompts (same as --ask-permissions).

Version: $VERSION
EOF
    exit 0
}

# --- INITIALIZATION ---

SCRIPT_DIR=$(get_script_dir)
# PROJECT_DIR is the root of the AIC repository (one level above scripts/).
# docker-compose.yml and worktrees/ live there, not inside scripts/.
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
VERSION="$(cat "$PROJECT_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "unknown")"

# MY_UID/MY_GID are read by docker-compose to run the container as the host user,
# ensuring that files written to /app are owned by the correct user on the host.
export MY_UID="$(id -u)"
export MY_GID="$(id -g)"

# --- ARGUMENT PARSING ---

INPUT=""
RESET=false
CLEANUP=""
SESSION_NAME=""
UPDATE=false
UNINSTALL=false
PURGE=false
BRANCH_PUSH=false
SKIP_CONFIRM=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -v|--version)
            echo "aic version $VERSION"
            exit 0
            ;;
        -n|--name)
            SESSION_NAME="$2"
            shift 2
            ;;
        --ask-permissions)
            export AGENT_ASK_PERMISSIONS=true
            shift
            ;;
        --reset)
            RESET=true
            shift
            ;;
        --cleanup=*)
            CLEANUP="${1#--cleanup=}"
            shift
            ;;
        -u|--update)
            UPDATE=true
            shift
            ;;
        -d|--uninstall)
            UNINSTALL=true
            shift
            ;;
        --purge)
            PURGE=true
            shift
            ;;
        --branch-push)
            BRANCH_PUSH=true
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRM=true
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

if [ "${AGENT_ASK_PERMISSIONS:-false}" == "true" ]; then
    echo "🔐 Permissions: Interactive (agent will ask before each action)"
else
    echo "🤖 Permissions: Autonomous (agent runs without permission prompts)"
fi

# --- ONE-SHOT ACTIONS (exit after completion) ---

# --update: pulls latest changes from git and rebuilds the Docker image.
if [ "$UPDATE" = true ]; then
    echo "🔄 Updating AI Agent Container..."
    git -C "$PROJECT_DIR" pull --ff-only || {
        echo "❌ git pull failed. Resolve any conflicts manually in $PROJECT_DIR."
        exit 1
    }
    docker compose -f "$COMPOSE_FILE" build
    echo "✅ Update complete."
    exit 0
fi

# --purge without --uninstall is not meaningful.
if [ "$PURGE" = true ] && [ "$UNINSTALL" = false ]; then
    echo "❌ --purge requires --uninstall. Did you mean: aic --uninstall --purge?"
    exit 1
fi

# --uninstall: delegates to uninstall.sh in the same directory.
if [ "$UNINSTALL" = true ]; then
    UNINSTALL_SCRIPT="$SCRIPT_DIR/uninstall.sh"
    if [ ! -f "$UNINSTALL_SCRIPT" ]; then
        echo "❌ Uninstall script not found: $UNINSTALL_SCRIPT"
        exit 1
    fi
    if [ "$PURGE" = true ]; then
        bash "$UNINSTALL_SCRIPT" --purge
    else
        bash "$UNINSTALL_SCRIPT"
    fi
    exit 0
fi

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

# --- WORKTREE SUPPORT ---

# Git worktrees use a .git *file* (not directory) containing an absolute path
# back to the main repo's .git/worktrees/<name> directory. When the worktree is
# bind-mounted as /app inside the container, that absolute path doesn't exist.
# Fix: detect worktrees and mount the main .git dir at its host path.
WORKTREE_EXTRA_ARGS=()

GIT_COMMON_DIR="$(git -C "$TARGET_PATH" rev-parse --git-common-dir 2>/dev/null)"
GIT_DIR="$(git -C "$TARGET_PATH" rev-parse --git-dir 2>/dev/null)"

if [ -n "$GIT_DIR" ] && [ -n "$GIT_COMMON_DIR" ]; then
    GIT_DIR_ABS="$(cd "$TARGET_PATH" && realpath "$GIT_DIR")"
    GIT_COMMON_DIR_ABS="$(cd "$TARGET_PATH" && realpath "$GIT_COMMON_DIR")"
    if [ "$GIT_DIR_ABS" != "$GIT_COMMON_DIR_ABS" ]; then
        # TARGET_PATH is a worktree — mount the main .git dir at its host path
        echo "🔗 Worktree detected: mounting $GIT_COMMON_DIR_ABS into container"
        WORKTREE_EXTRA_ARGS=(-v "$GIT_COMMON_DIR_ABS:$GIT_COMMON_DIR_ABS")
    fi
fi

# --- PUSH MODE ---

BRANCH_PUSH_EXTRA_ARGS=()

if [ "$BRANCH_PUSH" = true ]; then
    # Must be a git repo
    if ! git -C "$TARGET_PATH" rev-parse --git-dir > /dev/null 2>&1; then
        echo "❌ Error: --branch-push requires a Git repository, but '$TARGET_PATH' is not one."
        exit 1
    fi

    # Must not be in detached HEAD
    CURRENT_BRANCH="$(git -C "$TARGET_PATH" branch --show-current)"
    if [ -z "$CURRENT_BRANCH" ]; then
        echo "❌ Error: --branch-push requires a branch, but HEAD is detached."
        exit 1
    fi

    # Must not be main or master
    if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
        echo "❌ Error: --branch-push refuses to operate on '$CURRENT_BRANCH'. Create a branch first."
        exit 1
    fi

    # Confirmation prompt
    if [ "$SKIP_CONFIRM" = false ]; then
        echo ""
        echo "⚠️  Branch push mode: push limited to '$CURRENT_BRANCH' via git hook."
        echo "   Note: SSH keys will be accessible inside the container."
        read -r -p "   Continue? [y/N] " response
        if [[ ! "$response" =~ ^[yY]$ ]]; then
            echo "Aborted."
            exit 0
        fi
    fi

    echo "🔀 Push mode: branch-push (limited to '$CURRENT_BRANCH')"

    # Generate pre-push hook in a temp directory
    HOOK_DIR="$(mktemp -d)"
    cat > "$HOOK_DIR/pre-push" << HOOKEOF
#!/bin/bash
while read local_ref local_sha remote_ref remote_sha; do
    if [ "\$remote_ref" != "refs/heads/$CURRENT_BRANCH" ]; then
        echo "BLOCKED: push allowed only to '$CURRENT_BRANCH'"
        exit 1
    fi
done
HOOKEOF
    chmod +x "$HOOK_DIR/pre-push"

    # Generate gitconfig that points to the hooks directory
    GITCONFIG_FILE="$(mktemp)"
    cat > "$GITCONFIG_FILE" << GCEOF
[core]
    hooksPath = /etc/git-hooks
GCEOF

    # Extra docker args: mount hook, gitconfig, and SSH socket (all read-only)
    BRANCH_PUSH_EXTRA_ARGS=(
        -v "$HOOK_DIR:/etc/git-hooks:ro"
        -v "$GITCONFIG_FILE:/etc/gitconfig:ro"
        -v "${SSH_AUTH_SOCK}:/ssh-agent:ro"
        -e "SSH_AUTH_SOCK=/ssh-agent"
    )
else
    echo "🔒 Push mode: no-push (default)"
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
    docker compose -f "$COMPOSE_FILE" run --rm --name "$CONTAINER_NAME" \
        "${WORKTREE_EXTRA_ARGS[@]}" "${BRANCH_PUSH_EXTRA_ARGS[@]}" "$SERVICE"
fi