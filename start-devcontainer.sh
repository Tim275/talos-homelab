#!/bin/bash

# Build container if it doesn't exist
if ! docker image inspect talos-dev >/dev/null 2>&1; then
    echo "🔨 Building talos-dev container..."
    docker build -t talos-dev .devcontainer/
fi

# Start container with auto-trust
echo "🚀 Starting Talos K8s DevContainer..."
docker run -it --rm \
    --name talos-dev \
    --user vscode \
    -p 12000:12000 \
    -p 8080:8080 \
    -p 30080:30080 \
    -p 30081:30081 \
    -v "$(pwd)":/workspace \
    -v "$(pwd)/tofu/output/kube-config.yaml":/home/vscode/.kube/config \
    -v "$(pwd)/tofu/output/talos-config.yaml":/home/vscode/.talos/config \
    -v "$HOME/.ssh":/home/vscode/.ssh \
    --workdir /workspace \
    talos-dev bash -c "mise trust 2>/dev/null || true; exec bash"