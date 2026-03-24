# 🤖 Progetto: AI-Container (AIC)

Descrizione: Un ambiente di sviluppo isolato basato su Docker, progettato per permettere a un'AI di lavorare su codice sorgente senza sporcare l'host o accedere ai dati personali dell'utente.

## 🏗️ Architettura e Flusso di Lavoro

L'app utilizza un'immagine Ubuntu 24.04 personalizzata e uno script coordinatore (`ai-agent-container-run.sh`) che gestisce tre modalità operative:

- **Cartella corrente**: monta `$(pwd)` come `/app`
- **Cartella specifica**: monta un percorso esistente come `/app`
- **Git Worktree**: crea un ambiente isolato per una feature (`git worktree`), permettendo lo sviluppo in parallelo senza conflitti

### Variabili di controllo

| Variabile | Comportamento |
|-----------|---------------|
| `AGENT_MODE=ephemeral` (default) | La home dell'agente viene distrutta alla chiusura — sessioni indipendenti |
| `AGENT_MODE=persistent` | La home sopravvive tra le sessioni — Claude ricorda il contesto del progetto |
| `SESSION_NAME=<nome>` | Assegna un nome al container; se già in esecuzione, ri-aggancia automaticamente |
| `ANTHROPIC_API_KEY=<key>` | Autenticazione tramite API key Console (opzionale) |

## 🚀 Comandi Principali (sull'host)

```bash
# Build dell'immagine (una tantum o dopo modifiche al Dockerfile)
docker compose -f docker-compose.yml build

# Reset volume persistente dopo rebuild
AGENT_MODE=persistent ./ai-agent-container-run.sh --reset

# Avvio nella cartella corrente (effimero)
./ai-agent-container-run.sh

# Avvio su percorso specifico (persistente, con nome)
SESSION_NAME=myproject AGENT_MODE=persistent ./ai-agent-container-run.sh ~/projects/myapp

# Avvio su git worktree (crea branch ai/<nome>)
./ai-agent-container-run.sh feature-name
```

## 🛠️ Tool Stack (dentro il container)

- **Java**: OpenJDK 25 (Headless). Usa sempre `./gradlew`, non Gradle globale.
- **Python**: gestito esclusivamente tramite `uv`. Usa `uv run` o `uv add`.
- **JS/TS**: Bun (all-in-one). Usa `bun run` o `bun install`.
- **AI Tools**: Claude Code e OpenCode pre-installati.

## 🔒 Isolamento e Permessi

- **Home isolata**: `/home/ai-agent` è separata dalla home reale dell'host.
- **Mappatura Utente**: il container gira con il tuo UID/GID reale — i file creati in `/app` sono di tua proprietà.
- **Modalità effimera**: tutto fuori da `/app` scompare alla chiusura del container.
- **Modalità persistente**: il volume `ai_home_volume` sopravvive tra le sessioni.

## 📜 Regole per l'AI

Se sei l'AI che lavora in questo container, segui queste direttive:

- **Workdir**: lavora sempre dentro `/app`.
- **Dependencies**: non usare `apt-get`. Usa `uv add` (Python), `bun add` (JS) o aggiungi dipendenze a `build.gradle` (Java).
- **Persistenza**: in modalità effimera tutto ciò che scrivi in `/home/ai-agent` sparirà. Salva il codice solo in `/app`.
- **Permessi**: se `./gradlew` non è eseguibile, usa `chmod +x gradlew`.
