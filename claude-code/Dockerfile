FROM node:22-alpine

# System packages
RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    make \
    openssh \
    python3 \
    py3-pip \
    ripgrep \
    su-exec \
    wget

# uv (Python package manager)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# bun — install as the UID-1000 user so it lands in a home the runtime user can read
USER node
RUN curl -fsSL https://bun.com/install | bash
USER root
ENV PATH="/home/node/.bun/bin:${PATH}"

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
