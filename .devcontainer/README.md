# Talos K8s Devcontainer

##  Quick Start

```bash
# Build container



# Start container with auto-trust
echo " Starting Talos K8s DevContainer..."
docker run -it --rm \
    --name talos-dev \
    --user vscode \
    -v "$(pwd)":/workspace \
    -v "$(pwd)/tofu/output/kube-config.yaml":/home/vscode/.kube/config \
    -v "$(pwd)/tofu/output/talos-config.yaml":/home/vscode/.talos/config \
    -v "$HOME/.ssh":/home/vscode/.ssh \
    --workdir /workspace \
    talos-dev bash -c "mise trust 2>/dev/null || true; exec bash"
``` (auch mit talos bash :)

##  What's Included

- **mise** - Tool version manager
- **kubectl** - Kubernetes CLI (via mise)
- **k9s** - Kubernetes dashboard (via mise)
- **argocd** - GitOps CLI (via mise) 
- **yq** - YAML processor (via mise)
- **opentofu** - Infrastructure as Code (via mise)
- **talosctl** - Talos Linux CLI (via mise)

## 📁 Mounted Files

- `tofu/output/kube-config.yaml` → `~/.kube/config`
- `tofu/output/talos-config.yaml` → `~/.talos/config`
- `~/.ssh` → Container SSH keys


