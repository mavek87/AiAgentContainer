# Base: Ubuntu 24.04 LTS (Noble Numbat)
FROM ubuntu:24.04

# Evita interazioni durante l'installazione dei pacchetti
ENV DEBIAN_FRONTEND=noninteractive

# 1. Installazione dipendenze di sistema essenziali e OpenJDK 25 Headless
# Rimosso Python di sistema: useremo 'uv' per gestire runtime e pacchetti.
RUN apt-get update && apt-get install -y \
    curl \
    git \
    sudo \
    build-essential \
    unzip \
    ca-certificates \
    openjdk-25-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

# 2. Creazione dell'utente 'ai-agent' per l'isolamento (Security First)
# Questo utente verrà mappato con il tuo utente host tramite UID/GID al lancio.
RUN useradd -m -s /bin/bash ai-agent && \
    echo "ai-agent ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 3. Passaggio all'utente limitato per l'installazione dei tool di sviluppo
USER ai-agent
WORKDIR /home/ai-agent
RUN chmod 777 /home/ai-agent

# Installazione coordinata dei tool tramite i loro script ufficiali:
# - Claude Code & OpenCode: Cervelli AI
# - uv: Gestore Python ultra-rapido (sostituisce python3/pip/venv di sistema)
# - bun: Runtime JS/TS "all-in-one" (sostituisce Node/npm/yarn)
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    curl -fsSL https://opencode.ai/install | bash && \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    curl -fsSL https://bun.sh/install | bash && \
    mkdir -p /home/ai-agent/.claude /home/ai-agent/.config/opencode && \
    chmod -R a+rwX /home/ai-agent

# 4. Configurazione delle variabili d'ambiente (PATH e JAVA_HOME)
ENV PATH="/home/ai-agent/.local/bin:/home/ai-agent/.cargo/bin:/home/ai-agent/.bun/bin:$PATH"
ENV JAVA_HOME="/usr/lib/jvm/java-25-openjdk-amd64"

# 5. Definizione della cartella di lavoro per il Git Worktree
WORKDIR /app

# Comando di default: avvio della shell
CMD ["/bin/bash"]