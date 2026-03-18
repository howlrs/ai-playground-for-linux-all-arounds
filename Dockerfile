# =============================================================================
# AI Playground for Linux - All Arounds
# Claude Code (primary) + Gemini CLI (QA) + Codex + Full dev toolchain
# =============================================================================
FROM ubuntu:24.04

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
ARG NODE_MAJOR=22
ARG GO_VERSION=1.23.6
ARG RUST_VERSION=stable
ARG UV_VERSION=0.6

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
    cron \
    ripgrep \
    fd-find \
    build-essential \
    pkg-config \
    libssl-dev \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. Node.js (for Claude Code, Gemini CLI, Codex, gws, m365, Next.js)
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
RUN GLAB_VERSION=$(curl -s "https://gitlab.com/api/v4/projects/34675721/releases" | grep -o '"tag_name":"v[^"]*"' | head -1 | grep -o 'v[^"]*') \
    && GLAB_VER=${GLAB_VERSION#v} \
    && curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/${GLAB_VERSION}/downloads/glab_${GLAB_VER}_linux_amd64.deb" \
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
# 8. uv (Python package manager - replaces pip/venv/conda)
# ---------------------------------------------------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# ---------------------------------------------------------------------------
# 9. Create non-root user with full sudo
# ---------------------------------------------------------------------------
RUN userdel -r ubuntu 2>/dev/null || true \
    && groupdel ubuntu 2>/dev/null || true \
    && (groupadd --gid ${USER_GID} ${USERNAME} 2>/dev/null || true) \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
WORKDIR /home/${USERNAME}
ENV HOME=/home/${USERNAME}
ENV PATH="${HOME}/.cargo/bin:${HOME}/go/bin:${HOME}/.local/bin:${PATH}"

# ---------------------------------------------------------------------------
# 10. uv for user - install Python and set as managed
# ---------------------------------------------------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && uv python install 3.13 \
    && uv python pin 3.13
ENV UV_PYTHON_PREFERENCE=managed

# ---------------------------------------------------------------------------
# 11. Rust (user-level install)
# ---------------------------------------------------------------------------
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain ${RUST_VERSION}

# ---------------------------------------------------------------------------
# 12. AI Agents & Workspace tools (npm global → user prefix)
# ---------------------------------------------------------------------------
RUN mkdir -p "${HOME}/.npm-global" \
    && npm config set prefix "${HOME}/.npm-global"
ENV PATH="${HOME}/.npm-global/bin:${PATH}"

RUN npm install -g \
    @anthropic-ai/claude-code \
    @google/gemini-cli \
    @openai/codex \
    @googleworkspace/cli \
    @pnp/cli-microsoft365

# ---------------------------------------------------------------------------
# 13. Python tools via uv (global tool installs)
# ---------------------------------------------------------------------------
RUN uv tool install "notebooklm-py[browser]"
# msgraph-sdk, azure-identity are libraries (not CLI tools).
# Add them as project dependencies with: uv add msgraph-sdk azure-identity

# Playwright for notebooklm-py (needs browser binary)
RUN uvx --from "notebooklm-py[browser]" playwright install --with-deps chromium

# ---------------------------------------------------------------------------
# 14. Superpowers plugin (Claude Code skills framework)
# ---------------------------------------------------------------------------
RUN claude mcp add-from-claude-plugin -- superpowers-marketplace/superpowers 2>/dev/null || true

# ---------------------------------------------------------------------------
# 14.5. SurrealDB (AgentDB - multi-agent collective intelligence)
# ---------------------------------------------------------------------------
RUN curl -sSf https://install.surrealdb.com | sh
ENV PATH="${HOME}/.surrealdb:${PATH}"

# ---------------------------------------------------------------------------
# 15. Setup scripts directory
# ---------------------------------------------------------------------------
COPY --chown=${USERNAME}:${USERNAME} scripts/ ${HOME}/scripts/
RUN chmod +x ${HOME}/scripts/*.sh ${HOME}/scripts/agentdb

# Make agentdb available in PATH
RUN ln -s ${HOME}/scripts/agentdb ${HOME}/.local/bin/agentdb

# ---------------------------------------------------------------------------
# 16. Claude Code settings (full permissions inside container)
# ---------------------------------------------------------------------------
COPY --chown=${USERNAME}:${USERNAME} config/.claude/settings.json ${HOME}/.claude/settings.json

# ---------------------------------------------------------------------------
# 17. Agent guide files (copied to workspace root for discovery)
# ---------------------------------------------------------------------------
COPY --chown=${USERNAME}:${USERNAME} CLAUDE.md ${HOME}/CLAUDE.md
COPY --chown=${USERNAME}:${USERNAME} AGENTS.md ${HOME}/AGENTS.md
COPY --chown=${USERNAME}:${USERNAME} GEMINI.md ${HOME}/GEMINI.md

# ---------------------------------------------------------------------------
# 18. Example projects and scenarios (read-only templates)
# ---------------------------------------------------------------------------
COPY --chown=${USERNAME}:${USERNAME} examples/ ${HOME}/examples/

# ---------------------------------------------------------------------------
# Workspace
# ---------------------------------------------------------------------------
RUN mkdir -p ${HOME}/workspace
WORKDIR ${HOME}/workspace

CMD ["/bin/bash"]
