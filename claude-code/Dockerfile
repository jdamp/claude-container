FROM node:22-alpine

# System packages
RUN apk add --no-cache \
    bash \
    curl \
    font-roboto \
    fontconfig \
    git \
    jq \
    just \
    make \
    openssh \
    perl \
    python3 \
    py3-pip \
    ripgrep \
    su-exec \
    unzip \
    wget

# uv (Python package manager)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Rename the UID-1000 user from `node` to `claude` with home /home/claude.
# /home/claude is mounted as a persistent PVC at runtime, so anything written
# to it (shell history, tool configs, .ssh/authorized_keys) survives restarts.
RUN sed -i 's|^node:|claude:|; s|:/home/node:|:/home/claude:|' /etc/passwd && \
    sed -i 's|^node:|claude:|' /etc/group && \
    rm -rf /home/node && \
    mkdir -p /home/claude && \
    chown -R 1000:1000 /home/claude

# bun — installed via npm so it lands in /usr/local/bin, independent of $HOME
RUN npm install -g bun

# Fonts
COPY install-fonts.sh /tmp/install-fonts.sh
RUN chmod +x /tmp/install-fonts.sh && /tmp/install-fonts.sh && rm /tmp/install-fonts.sh

# typst
ARG TYPST_VERSION=0.13.1
RUN wget -qO- "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-x86_64-unknown-linux-musl.tar.xz" \
    | tar -xJf - --strip-components=1 -C /usr/local/bin/ "typst-x86_64-unknown-linux-musl/typst"

# Claude Code CLI
ARG CLAUDE_CODE_VERSION=latest
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Config and workspace directories
RUN mkdir -p /claude /workspace

ENV CLAUDE_CONFIG_DIR=/claude

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
CMD ["claude"]
