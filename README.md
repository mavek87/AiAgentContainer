# AI Agent Container (AIC)

Isolated Docker container for AI development sessions. The agent works inside `/app` (your project folder) without touching the rest of the host system.

## Installation

**One-liner (recommended):**

```bash
curl -fsSL https://raw.githubusercontent.com/mavek87/AiAgentContainer/main/scripts/install.sh | bash
```

This clones the repo to `~/.local/share/aic`, builds the Docker image, and installs the `aic` command.

**From a local clone:**

```bash
cd /path/to/AiAgentContainer
./scripts/install.sh
```

---

**Update:**

```bash
aic --update   # pull latest changes and rebuild the image
```

**Uninstall:**

```bash
~/.local/share/aic/scripts/uninstall.sh            # remove 'aic' command
~/.local/share/aic/scripts/uninstall.sh --purge    # also remove Docker image and volumes
```

---

## Usage

```bash
# Current directory
aic

# Specific directory
aic ~/projects/my-app

# Git worktree — creates branch ai/new-feature in ./worktrees/new-feature
aic new-feature
```

Close the session with `exit`. The container is removed automatically.

---

## Options and environment variables

| Option / Variable | Values | Default | Description |
|---|---|---|---|
| `-n`, `--name <name>` | any string | — | Name the session; re-attaches if already running |
| `--reset` | — | — | Delete the persistent home volume (requires `AGENT_MODE=persistent`) |
| `--cleanup=<name>` | worktree name | — | Remove a git worktree and its branch |
| `--update` | — | — | Pull latest changes from git and rebuild the Docker image |
| `AGENT_MODE` | `ephemeral` \| `persistent` | `ephemeral` | Session mode |
| `ANTHROPIC_API_KEY` | `sk-ant-...` | — | Console API key (optional) |

---

## Session modes

**Ephemeral (default)** — the agent's home directory is destroyed on exit. Every session starts from scratch.

```bash
aic ~/projects/my-app
```

**Persistent** — the home directory survives between sessions. Claude remembers project context and conversation history.

```bash
AGENT_MODE=persistent aic ~/projects/my-app
```

---

## Claude authentication

**Pro/Max subscription**: use `AGENT_MODE=persistent` and run `claude login` once on first start. The session is saved in the `ai_home_volume` Docker volume and stays valid across future sessions.

**Console API key**: set `ANTHROPIC_API_KEY` on the host before launching. Works with both modes.

> Claude Pro OAuth is browser-based and cannot be transferred between installations. There is no way to share host credentials with the container.

---

## Named sessions

`--name` assigns a name to the container. If a session with that name is already running, the script opens a new shell inside it instead of starting a second instance.

```bash
# Terminal 1 — start
AGENT_MODE=persistent aic --name backend ~/projects/backend

# Terminal 2 — auto re-attach
AGENT_MODE=persistent aic --name backend ~/projects/backend
# → 🔗 Session 'backend' is already running — opening new shell...
```

---

## Practical examples

**One-shot task (ephemeral):**
```bash
cd ~/projects/backend
aic
# inside the container: claude "add validation to the /users endpoint"
```

**Isolated feature on a worktree:**
```bash
cd ~/projects/backend
aic refactor-auth
# the AI works on worktrees/refactor-auth, main is untouched
# when done: aic --cleanup=refactor-auth
```

**Multi-day session with memory:**
```bash
AGENT_MODE=persistent aic --name payments ~/projects/my-app
# exit — resume the next day with the same command
```

**Parallel sessions:**
```bash
AGENT_MODE=persistent aic --name backend  ~/projects/backend   # terminal 1
AGENT_MODE=persistent aic --name frontend ~/projects/frontend  # terminal 2
```

**Reset volume after rebuild:**
```bash
docker compose build
AGENT_MODE=persistent aic --reset
```

---

## SSH and remote Git

To enable `git pull/push` to remote repositories (GitHub, GitLab, etc.), the container uses **SSH agent forwarding**: it shares the host's SSH keys without copying them into the container.

```bash
# Verify ssh-agent is running and has keys loaded
echo $SSH_AUTH_SOCK   # should return a path (e.g. /run/user/1000/gcr/ssh)
ssh-add -l            # list loaded keys

# If ssh-agent is not running or has no keys:
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Once active, launch the container normally — `git pull/push` will work automatically.

---

## Worktree cleanup

When you are done with a worktree feature, remove it with `--cleanup`:

```bash
# Removes worktrees/refactor-auth and branch ai/refactor-auth
aic --cleanup=refactor-auth
```

Or manually:
```bash
git worktree remove worktrees/refactor-auth
git branch -d ai/refactor-auth
```
