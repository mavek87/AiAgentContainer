# 🤖 Project: AI-Agent-Container (AIAC)

Description: An isolated development environment based on Docker, designed to allow an AI to work on source code without cluttering the host or accessing the user's personal data.

## 🏗️ Architecture and Workflow

The app uses a customized Ubuntu 24.04 image and a coordinator script (`ai-agent-container-run.sh`) that manages three operating modes:

- **Current folder**: mounts `$(pwd)` as `/app`
- **Specific folder**: mounts an existing path as `/app`
- **Git Worktree**: creates an isolated environment for a feature (`git worktree`), allowing parallel development without conflicts

### Control Variables

| Variable | Behavior |
|-----------|---------------|
| `AGENT_MODE=ephemeral` (default) | The agent's home is destroyed upon closing — independent sessions |
| `AGENT_MODE=persistent` | The home survives between sessions — Claude remembers the project context |
| `SESSION_NAME=<name>` | Assigns a name to the container; if already running, it automatically re-attaches |
| `ANTHROPIC_API_KEY=<key>` | Authentication via Console API key (optional) |

## 🚀 Main Commands (on host)

```bash
# Build the image (one-time or after Dockerfile changes)
docker compose -f docker-compose.yml build

# Reset persistent volume after rebuild
AGENT_MODE=persistent ./ai-agent-container-run.sh --reset

# Start in current folder (ephemeral)
./ai-agent-container-run.sh

# Start on specific path (persistent, with name)
SESSION_NAME=myproject AGENT_MODE=persistent ./ai-agent-container-run.sh ~/projects/myapp

# Start on git worktree (creates branch ai/<name>)
./ai-agent-container-run.sh feature-name
```

## 🛠️ Tool Stack (inside the container)

- **Java**: OpenJDK 25 (Headless). Always use `./gradlew`, not global Gradle.
- **Python**: managed exclusively via `uv`. Use `uv run` or `uv add`.
- **JS/TS**: Bun (all-in-one). Use `bun run` or `bun install`.
- **AI Tools**: Claude Code and OpenCode pre-installed.

## 🔒 Isolation and Permissions

- **Isolated Home**: `/home/ai-agent` is separate from the real host home.
- **User Mapping**: the container runs with your real UID/GID — files created in `/app` are owned by you.
- **Ephemeral mode**: everything outside `/app` disappears when the container is closed.
- **Persistent mode**: the `ai_home_volume` volume survives between sessions.

## 📜 Rules for the AI

If you are the AI working in this container, follow these directives:

- **Workdir**: always work inside `/app`.
- **Dependencies**: do not use `apt-get`. Use `uv add` (Python), `bun add` (JS) or add dependencies to `build.gradle` (Java).
- **Persistence**: in ephemeral mode, everything you write in `/home/ai-agent` will disappear. Save code only in `/app`.
- **Permissions**: if `./gradlew` is not executable, use `chmod +x gradlew`.
