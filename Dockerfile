# =============================================================================
# AI Playground for Linux - All Arounds
# Claude Code (primary) + Gemini CLI (QA agent) + Full dev toolchain
# =============================================================================
FROM ubuntu:24.04

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
ARG NODE_MAJOR=22
ARG GO_VERSION=1.23.6
ARG RUST_VERSION=stable

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ---------------------------------------------------------------------------
# 1. Base system packages
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    gnupg \
    unzip \
    git \
    sudo \
    vim \
    tmux \
    jq \
    ripgrep \
    fd-find \
    build-essential \
    pkg-config \
    libssl-dev \
    python3 \
    python3-pip \
    python3-venv \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. Node.js (for Claude Code, Gemini CLI, gws, Next.js)
# ---------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 3. GitHub CLI (gh)
# ---------------------------------------------------------------------------
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && wget -nv -O /etc/apt/keyrings/githubcli-archive-keyring.gpg \
       https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 4. GitLab CLI (glab)
# ---------------------------------------------------------------------------
RUN curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/permalink/latest/downloads/glab_linux_amd64.deb" \
       -o /tmp/glab.deb \
    && dpkg -i /tmp/glab.deb \
    && rm /tmp/glab.deb

# ---------------------------------------------------------------------------
# 5. Google Cloud SDK (gcloud)
# ---------------------------------------------------------------------------
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
       | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
       > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update && apt-get install -y google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 6. AWS CLI v2
# ---------------------------------------------------------------------------
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
       -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# ---------------------------------------------------------------------------
# 7. Go
# ---------------------------------------------------------------------------
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
       | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

# ---------------------------------------------------------------------------
# 8. Create non-root user with full sudo
# ---------------------------------------------------------------------------
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
WORKDIR /home/${USERNAME}
ENV HOME=/home/${USERNAME}
ENV PATH="${HOME}/.cargo/bin:${HOME}/go/bin:${HOME}/.local/bin:${PATH}"

# ---------------------------------------------------------------------------
# 9. Rust (user-level install)
# ---------------------------------------------------------------------------
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain ${RUST_VERSION}

# ---------------------------------------------------------------------------
# 10. AI Agents & Workspace tools (npm global → user prefix)
# ---------------------------------------------------------------------------
RUN mkdir -p "${HOME}/.npm-global" \
    && npm config set prefix "${HOME}/.npm-global"
ENV PATH="${HOME}/.npm-global/bin:${PATH}"

RUN npm install -g \
    @anthropic-ai/claude-code \
    @google/gemini-cli \
    @googleworkspace/cli

# ---------------------------------------------------------------------------
# 11. Python tools (notebooklm-py)
# ---------------------------------------------------------------------------
RUN python3 -m venv "${HOME}/.venv" \
    && . "${HOME}/.venv/bin/activate" \
    && pip install --no-cache-dir "notebooklm-py[browser]" \
    && playwright install --with-deps chromium
ENV PATH="${HOME}/.venv/bin:${PATH}"

# ---------------------------------------------------------------------------
# 12. Setup scripts directory
# ---------------------------------------------------------------------------
COPY --chown=${USERNAME}:${USERNAME} scripts/ ${HOME}/scripts/
RUN chmod +x ${HOME}/scripts/*.sh

# ---------------------------------------------------------------------------
# Workspace
# ---------------------------------------------------------------------------
RUN mkdir -p ${HOME}/workspace
WORKDIR ${HOME}/workspace

CMD ["/bin/bash"]
