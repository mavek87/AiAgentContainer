# 🤖 Project: AI Agent Container (AIC)

An isolated development environment based on Docker, designed to allow an AI to work on source code without cluttering the host or accessing the user's personal data.

## 🏗️ Architecture and Workflow

The project uses a customized Ubuntu 24.04 image and a coordinator script (`scripts/ai-agent-container-run.sh`) that manages three operating modes:

- **Current folder**: mounts `$(pwd)` as `/app`
- **Specific folder**: mounts an existing path as `/app`
- **Git Worktree**: creates an isolated environment for a feature (`git worktree`), allowing parallel development without conflicts

### Options and Environment Variables

| Option / Variable | Behavior |
|---|---|
| `AGENT_MODE=ephemeral` (default) | The agent's home is destroyed on exit — clean slate every session |
| `AGENT_MODE=persistent` | The home survives between sessions — Claude remembers project context |
| `-n`, `--name <name>` | Names the container; re-attaches automatically if already running |
| `--reset` | Deletes the persistent home volume (requires `AGENT_MODE=persistent`) |
| `--cleanup=<name>` | Removes a git worktree and its tracking branch |
| `--branch-push` | Allows git push only to the current branch (mounts SSH keys, requires confirmation) |
| `-y`, `--yes` | Skips confirmation prompts |
| `ANTHROPIC_API_KEY=<key>` | Authentication via Console API key (optional) |

## 🚀 Main Commands (on host)

```bash
# Build the image (one-time or after Dockerfile changes)
docker compose build

# Reset persistent volume after rebuild
AGENT_MODE=persistent aic --reset

# Start in current folder (ephemeral)
aic

# Start on a specific path (persistent, named session)
AGENT_MODE=persistent aic --name myproject ~/projects/myapp

# Start on a git worktree (creates branch ai/<name>)
aic feature-name

# Clean up a worktree when done
aic --cleanup=feature-name
```

## 🛠️ Tool Stack (inside the container)

- **Java**: OpenJDK 25 (Headless). Always use `./gradlew`, not global Gradle.
- **Python**: managed exclusively via `uv`. Use `uv run` or `uv add`.
- **JS/TS**: Bun (all-in-one). Use `bun run` or `bun install`.
- **AI Tools**: Claude Code and OpenCode pre-installed (always latest version).

## 🔒 Isolation and Permissions

- **Isolated Home**: `/home/ubuntu` is separate from the real host home.
- **User Mapping**: the container runs with your real UID/GID — files created in `/app` are owned by you.
- **No-push (default)**: git push is disabled — no SSH keys are mounted. The agent can commit locally but cannot push.
- **Branch-push (`--branch-push`)**: git push is allowed only to the current branch via a read-only git hook. SSH keys are accessible inside the container.
- **Ephemeral mode**: everything outside `/app` disappears when the container exits.
- **Persistent mode**: the `ai_home_volume` Docker volume survives between sessions.

## 📜 Rules for the AI

If you are the AI working in this container, follow these directives:

- **Workdir**: always work inside `/app`.
- **Dependencies**: do not use `apt` to install packages — changes are volatile and non-reproducible. Use `uv add` (Python), `bun add` (JS), or add dependencies to `build.gradle` (Java).
- **Persistence**: in ephemeral mode, everything you write in `/home/ubuntu` will disappear on exit. Save code only in `/app`.
- **Permissions**: if `./gradlew` is not executable, run `chmod +x gradlew`.
- **Git user**: you are running as `ubuntu`.
