# AIAgentContainer (AIC)

Container Docker isolato per sessioni di sviluppo con AI. L'agente lavora dentro `/app` (la tua cartella di progetto) senza toccare il resto del sistema host.

## Prerequisiti

```bash
# Costruisci l'immagine (una tantum, o dopo modifiche al Dockerfile)
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

## Variabili d'ambiente

| Variabile | Valori | Default | Descrizione |
|-----------|--------|---------|-------------|
| `AGENT_MODE` | `ephemeral` \| `persistent` | `ephemeral` | Modalità sessione |
| `SESSION_NAME` | qualsiasi stringa | — | Nome del container |
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

`SESSION_NAME` assegna un nome al container. Se una sessione con quel nome è già in esecuzione, lo script si ri-aggancia automaticamente.

```bash
# Terminale 1 — avvia
SESSION_NAME=backend AGENT_MODE=persistent /path/to/ai-agent-container-run.sh ~/progetti/backend

# Terminale 2 — ri-aggancio automatico
SESSION_NAME=backend AGENT_MODE=persistent /path/to/ai-agent-container-run.sh ~/progetti/backend
# → 🔗 Session 'backend' is already running — attaching...
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
SESSION_NAME=pagamenti AGENT_MODE=persistent /path/to/ai-agent-container-run.sh ~/progetti/mia-app
# exit — riprendi il giorno dopo con lo stesso comando
```

**Più sessioni parallele:**
```bash
SESSION_NAME=backend  AGENT_MODE=persistent /path/to/ai-agent-container-run.sh ~/progetti/backend   # terminale 1
SESSION_NAME=frontend AGENT_MODE=persistent /path/to/ai-agent-container-run.sh ~/progetti/frontend  # terminale 2
```

**Reset volume dopo rebuild:**
```bash
docker compose -f /path/to/AIAgentContainer/docker-compose.yml build
AGENT_MODE=persistent /path/to/ai-agent-container-run.sh --reset
```
