FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

COPY --from=jdxcode/mise /usr/local/bin/mise /usr/local/bin/

# Install Cilium CLI (funktioniert für ARM und x86_64)
ARG CILIUM_CLI_VERSION="v0.18.5"
RUN ARCH="$(dpkg --print-architecture)" && \
    curl -L -o cilium.tar.gz https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz && \
    tar -xzf cilium.tar.gz && \
    install -m 0755 cilium /usr/local/bin/cilium && \
    rm cilium cilium.tar.gz

# mise Shell-Integration (ohne Fehler beim Start)
RUN mise activate bash >> /home/vscode/.bashrc && \
    mise activate zsh >> /home/vscode/.zshrc

# Hinweis: Für ARM- und x86-Container geeignet!