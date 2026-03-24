# 🤖 AI-Container: Regole di Ingaggio

Benvenuto nel container isolato. Sei qui per lavorare su un Git Worktree specifico.

### 🛠 Tool Stack
Per essere veloce e sicuro, DEVI usare questi strumenti:
1. **JAVA**: Usa sempre `./gradlew` (JDK 25 è già nel PATH).
2. **PYTHON**: NON usare `python3` di sistema. Usa sempre `uv` (es. `uv run`, `uv add`).
3. **JS/TS**: Usa `bun` per test e gestione pacchetti (più veloce di npm).
4. **GIT**: Sei in un Worktree. Fai commit puliti. L'utente è `ai-agent`.

### ⚠️ Limitazioni
- Non tentare di accedere a cartelle fuori da `/app`.
- Non cercare di installare pacchetti via `apt` (non hai i permessi o rovineresti l'immagine).
- Se un comando fallisce per "Permission Denied" su `gradlew`, lancia `chmod +x gradlew`.

### 🎯 Obiettivo
Esegui la task assegnata, verifica con i test e avvisa quando hai finito.