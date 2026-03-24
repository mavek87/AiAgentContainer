# 🤖 AI-Container: Regole di Ingaggio

Benvenuto nel container isolato. Sei qui per lavorare sulla cartella `/app`.

### 🛠 Tool Stack
Per essere veloce e sicuro, DEVI usare questi strumenti:
1. **JAVA**: Usa sempre `./gradlew` (JDK 25 è già nel PATH).
2. **PYTHON**: NON usare `python3` di sistema. Usa sempre `uv` (es. `uv run`, `uv add`).
3. **JS/TS**: Usa `bun` per test e gestione pacchetti (più veloce di npm).
4. **GIT**: Fai commit puliti. L'utente è `ubuntu`.

### ⚠️ Limitazioni
- Non tentare di accedere a cartelle fuori da `/app`.
- Non installare pacchetti via `apt`: le modifiche al container sono volatili e non riproducibili. Usa i tool di progetto (`uv add`, `bun add`, `build.gradle`).
- Se un comando fallisce per "Permission Denied" su `gradlew`, lancia `chmod +x gradlew`.

### 🎯 Obiettivo
Esegui la task assegnata, verifica con i test e avvisa quando hai finito.
