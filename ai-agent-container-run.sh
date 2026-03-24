#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export MY_UID=$(id -u)
export MY_GID=$(id -g)

# Autenticazione Claude
# - API key: imposta ANTHROPIC_API_KEY sull'host
# - Pro subscription: usa AGENT_MODE=persistent e fai 'claude login' una volta sola
if [ -n "${ANTHROPIC_API_KEY}" ]; then
    echo "🔑 Claude auth: API key"
else
    echo "ℹ️  Claude auth: nessuna API key — usa AGENT_MODE=persistent e fai 'claude login' al primo avvio"
fi

# Parsing argomenti
INPUT=""
RESET=false
for arg in "$@"; do
    if [ "$arg" == "--reset" ]; then
        RESET=true
    else
        INPUT="$arg"
    fi
done

# Selezione modalità: ephemeral (default) o persistent
if [ "${AGENT_MODE}" == "persistent" ]; then
    SERVICE="agent"
    echo "💾 Session: Persistent (home survives between sessions)"
else
    SERVICE="agent-ephemeral"
    echo "🧹 Session: Ephemeral (home is discarded on exit)"
fi

# --reset: rimuove il volume della home persistente (utile dopo docker compose build)
if [ "$RESET" = true ]; then
    if [ "$SERVICE" == "agent" ]; then
        PROJECT=$(docker compose -f "$SCRIPT_DIR/docker-compose.yml" config --project-name 2>/dev/null)
        VOLUME_NAME="${PROJECT}_ai_home_volume"
        echo "🗑️  Removing persistent home volume: $VOLUME_NAME"
        docker volume rm "$VOLUME_NAME" 2>/dev/null && echo "✅ Done" || echo "⚠️  Volume not found (already removed?)"
    else
        echo "⚠️  --reset è utile solo con AGENT_MODE=persistent"
    fi
fi

# Logica di selezione del Target
if [ -z "$INPUT" ] || [ "$INPUT" == "." ]; then
    export TARGET_PATH=$(pwd)
    echo "📂 Target: Current Directory ($TARGET_PATH)"
elif [ -d "$INPUT" ]; then
    export TARGET_PATH=$(realpath "$INPUT")
    echo "📂 Target: Existing Directory ($TARGET_PATH)"
else
    # Se non è una cartella, la trattiamo come una Git Feature
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "❌ Errore: non sei in una repository Git. La modalità worktree richiede un repo git."
        exit 1
    fi
    WORKTREE_DIR="./worktrees/$INPUT"
    if [ ! -d "$WORKTREE_DIR" ]; then
        echo "🌿 Creating Git Worktree: $INPUT"
        git worktree add -b "ai/$INPUT" "$WORKTREE_DIR" HEAD
    fi
    export TARGET_PATH=$(realpath "$WORKTREE_DIR")
    echo "🌳 Target: Git Worktree ($TARGET_PATH)"
fi

# Lancio
if [ -n "${SESSION_NAME}" ]; then
    CONTAINER_NAME="aic-${SESSION_NAME}"
    if docker inspect --format '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q true; then
        echo "🔗 Session '$SESSION_NAME' is already running — attaching..."
        docker attach "$CONTAINER_NAME"
    else
        echo "🏷️  Session: $SESSION_NAME"
        docker compose -f "$SCRIPT_DIR/docker-compose.yml" run --rm --name "$CONTAINER_NAME" "$SERVICE"
    fi
else
    docker compose -f "$SCRIPT_DIR/docker-compose.yml" run --rm "$SERVICE"
fi
