FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

COPY --from=jdxcode/mise /usr/local/bin/mise /usr/local/bin/

# Install Cilium CLI
RUN CILIUM_CLI_VERSION="v0.18.5" && \
    curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz && \
    tar xzf cilium-linux-amd64.tar.gz && \
    mv cilium /usr/local/bin/ && \
    rm cilium-linux-amd64.tar.gz

# make sure mise is activated in both zsh and bash. Might be overridden by a user's dotfiles.
RUN echo 'eval "$(mise activate bash)"' >> /home/vscode/.bashrc && \
  echo 'eval "$(mise activate zsh)"' >> /home/vscode/.zshrc