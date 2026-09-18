FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04@sha256:d94c97dd9cacf183d0a6fd12a8e87b526e9e928307674ae9c94139139c0c6eae

COPY --from=jdxcode/mise@sha256:f01b88463f3a8396b2273d88469bd09d097aa3cacfe343177eb5457f1d8d2a92 /usr/local/bin/mise /usr/local/bin/

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