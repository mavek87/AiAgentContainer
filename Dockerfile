# Base: Ubuntu 24.04 LTS (Noble Numbat)
FROM ubuntu:24.04

# Use bash with pipefail to ensure any command failure in a pipeline
# (like curl | bash) exits the build immediately with an error.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# 1. System dependencies and User configuration
# Combined to reduce layers while keeping related system-level tasks together.
# --no-install-recommends avoids installing unnecessary packages, keeping the image slim.
RUN apt-get update && apt-get install -y \
    curl \
    git \
    sudo \
    build-essential \
    unzip \
    ca-certificates \
    vim \
    jq \
    openjdk-25-jdk-headless \
    && rm -rf /var/lib/apt/lists/* \
    && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd \
    && chmod 0440 /etc/sudoers.d/nopasswd \
    && echo "    StrictHostKeyChecking accept-new" >> /etc/ssh/ssh_config

# 2. Switch to 'ubuntu' user (default UID 1000 in Noble) for tool installation
USER ubuntu
WORKDIR /home/ubuntu

# 3. Development tools installation
# Grouped in one RUN command to minimize layer count.
# Uses official installers for Claude, OpenCode, Astral (uv), and Bun.
RUN mkdir -p /home/ubuntu/.claude /home/ubuntu/.config/opencode \
    && curl -fsSL https://claude.ai/install.sh | bash \
    && curl -fsSL https://opencode.ai/install | bash \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && curl -fsSL https://bun.sh/install | bash \
    && mv /home/ubuntu/.local/bin/claude /home/ubuntu/.local/bin/claude-real

# 4. Config files: claude wrapper, statusline script, claude settings
# The real 'claude' binary is replaced with a wrapper that injects
# --dangerously-skip-permissions unless AGENT_ASK_PERMISSIONS=true is set.
USER root
COPY --chown=ubuntu:ubuntu config/claude-wrapper.sh /home/ubuntu/.local/bin/claude
COPY --chown=ubuntu:ubuntu config/claude-settings.json /home/ubuntu/.claude/settings.json
COPY --chown=ubuntu:ubuntu config/statusline-command.sh /home/ubuntu/.claude/statusline-command.sh
COPY config/opencode-settings.json /etc/aic/opencode-settings.json
RUN chmod +x /home/ubuntu/.local/bin/claude /home/ubuntu/.claude/statusline-command.sh

# 5. Java Environment Setup + container entrypoint
# Dynamically locate JAVA_HOME to support multiple architectures (amd64/arm64).
# The entrypoint script configures tools based on AGENT_ASK_PERMISSIONS at runtime.
RUN ln -sf "$(dirname "$(dirname "$(readlink -f "$(which java)")")")" /usr/lib/jvm/active-java
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
USER ubuntu

# 6. Environment variables
# Update PATH to include local binaries and cargo/bun paths
ENV PATH="/home/ubuntu/.local/bin:/home/ubuntu/.cargo/bin:/home/ubuntu/.bun/bin:$PATH"
ENV JAVA_HOME="/usr/lib/jvm/active-java"

# 6. Final workspace setup
WORKDIR /app

# Entrypoint configures tools (permissions mode) then hands off to CMD.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]