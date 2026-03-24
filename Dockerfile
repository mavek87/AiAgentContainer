# Base: Ubuntu 24.04 LTS (Noble Numbat)
FROM ubuntu:24.04

# Avoid interaction during package installation
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install essential system dependencies and OpenJDK 25 Headless
RUN apt-get update && apt-get install -y \
    curl \
    git \
    sudo \
    build-essential \
    unzip \
    ca-certificates \
    openjdk-25-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

# 2. Grant passwordless sudo to the 'ubuntu' user (UID 1000, pre-existing in base image)
# The container runs with the host UID/GID — on most Linux desktops this is 1000 = ubuntu.
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd && \
    chmod 0440 /etc/sudoers.d/nopasswd

# 3. Switch to ubuntu user for tool installation
USER ubuntu
WORKDIR /home/ubuntu

# 4. Install development tools via their official scripts (always latest):
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    curl -fsSL https://opencode.ai/install | bash && \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    curl -fsSL https://bun.sh/install | bash && \
    mkdir -p /home/ubuntu/.claude /home/ubuntu/.config/opencode

# 5. Environment variables (PATH and JAVA_HOME)
# JAVA_HOME is detected dynamically via symlink to support any architecture (amd64, arm64, ...)
USER root
RUN ln -sf "$(dirname "$(dirname "$(readlink -f "$(which java)")")")" /usr/lib/jvm/active-java
USER ubuntu
ENV PATH="/home/ubuntu/.local/bin:/home/ubuntu/.cargo/bin:/home/ubuntu/.bun/bin:$PATH"
ENV JAVA_HOME="/usr/lib/jvm/active-java"

# 6. Working directory
WORKDIR /app

CMD ["/bin/bash"]