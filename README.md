# AIAgentContainer (AIC)

Isolated Docker container for AI development sessions. The agent works inside `/app` (your project folder) without touching the rest of the host system.

## Prerequisites

```bash
# Build the image (one-time, or after Dockerfile changes)
docker compose -f /path/to/AIAgentContainer/docker-compose.yml build
```

---

## Utilizzo

```bash
# Cartella corrente
/path/to/ai-agent-container-run.sh

# Cartella specifica
/path/to/ai-agent-container-run.sh ~/progetti/mia-app

# Git worktree — crea branch ai/nuova-feature in ./worktrees/nuova-feature
/path/to/ai-agent-container-run.sh nuova-feature
```

Chiudi la sessione con `exit`. Il container viene rimosso automaticamente.

---

## Opzioni e variabili d'ambiente

| Parametro / Variabile | Valori | Default | Descrizione |
|-----------|--------|---------|-------------|
| `-n`, `--name <nome>` | qualsiasi stringa | — | Nome della sessione (ri-aggancio automatico se già attiva) |
| `AGENT_MODE` | `ephemeral` \| `persistent` | `ephemeral` | Modalità sessione |
| `ANTHROPIC_API_KEY` | `sk-ant-...` | — | API key Console (opzionale) |

---

## Modalità sessione

**Effimera (default)** — la home dell'agente viene distrutta alla chiusura. Ogni sessione riparte da zero.

```bash
/path/to/ai-agent-container-run.sh ~/progetti/mia-app
```

**Persistente** — la home sopravvive tra le sessioni. Claude ricorda conversazioni e contesto del progetto.

```bash
AGENT_MODE=persistent /path/to/ai-agent-container-run.sh ~/progetti/mia-app
```

---

## Autenticazione Claude

**Pro/Max subscription**: usa `AGENT_MODE=persistent` e fai `claude login` una volta sola al primo avvio. La sessione viene salvata nel volume `ai_home_volume` e rimane valida per tutte le sessioni successive.

**API key Console**: imposta `ANTHROPIC_API_KEY` sull'host prima di lanciare lo script. Funziona in entrambe le modalità.

> L'OAuth di Claude Pro è browser-based e non trasferibile tra installazioni. Non esiste modo di condividere le credenziali dell'host con il container.

---

## Sessioni con nome

`--name` assegna un nome al container. Se una sessione con quel nome è già in esecuzione, lo script apre una nuova shell nella sessione esistente.

```bash
# Terminale 1 — avvia
AGENT_MODE=persistent /path/to/ai-agent-container-run.sh --name backend ~/progetti/backend

# Terminale 2 — ri-aggancio automatico
AGENT_MODE=persistent /path/to/ai-agent-container-run.sh --name backend ~/progetti/backend
# → 🔗 Session 'backend' is already running — opening new shell...
```

---

## Casi d'uso pratici

**Task one-shot (ephemeral):**
```bash
cd ~/progetti/backend
/path/to/ai-agent-container-run.sh
# dentro il container: claude "aggiungi validazione all'endpoint /users"
```

**Feature isolata su worktree:**
```bash
cd ~/progetti/backend
/path/to/ai-agent-container-run.sh refactor-auth
# l'AI lavora su worktrees/refactor-auth, main è intatto
# quando finisci: git worktree remove worktrees/refactor-auth
```

**Sessione multi-giorno con memoria:**
```bash
AGENT_MODE=persistent /path/to/ai-agent-container-run.sh --name pagamenti ~/progetti/mia-app
# exit — riprendi il giorno dopo con lo stesso comando
```

**Più sessioni parallele:**
```bash
AGENT_MODE=persistent /path/to/ai-agent-container-run.sh --name backend  ~/progetti/backend   # terminale 1
AGENT_MODE=persistent /path/to/ai-agent-container-run.sh --name frontend ~/progetti/frontend  # terminale 2
```

**Reset volume dopo rebuild:**
```bash
docker compose -f /path/to/AIAgentContainer/docker-compose.yml build
AGENT_MODE=persistent /path/to/ai-agent-container-run.sh --reset
```

---

## SSH e Git remoti

Per abilitare `git pull/push` verso repository remoti (GitHub, GitLab, ecc.) il container usa **SSH agent forwarding**: condivide le chiavi SSH dell'host senza copiarle nel container.

```bash
# Verifica che ssh-agent sia attivo e abbia le chiavi caricate
echo $SSH_AUTH_SOCK      # deve restituire un path (es. /run/user/1000/gcr/ssh)
ssh-add -l               # lista le chiavi caricate

# Se ssh-agent non è attivo o non ha chiavi:
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Una volta attivo, avvia il container normalmente — `git pull/push` funzionerà automaticamente.

---

## Cleanup worktree

Quando hai finito con una feature su worktree, rimuovila con il flag `--cleanup`:

```bash
# Rimuove worktrees/refactor-auth e il branch ai/refactor-auth
/path/to/ai-agent-container-run.sh --cleanup=refactor-auth
```

Oppure manualmente:
```bash
git worktree remove worktrees/refactor-auth
git branch -d ai/refactor-auth
```
