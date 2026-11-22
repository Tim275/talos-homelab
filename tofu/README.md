# tofu

- `stacks/`: ein Root-Modul je State. `cluster` (Proxmox-VMs, Talos, OpenBao-Seed), `proxmox` (Hosts, Storages, Tokens; nur lokal mit root@pam), `netbird`, `uptime-kuma`, `harbor` (Projekte, Robots, Garbage Collection), `state` (das Azure-Backend selbst).
- `modules/`: Bausteine, die nur aus den Stacks heraus benutzt werden (`talos`, `openbao`).

Lokal braucht der Cluster-Stack in `stacks/cluster` die Startwerte `openbao_values.auto.tfvars`, den Seal-Key `keys/seal.key` und die Ceph-Zugänge `rook_external.auto.tfvars` (`mise run pve-rook-export`). Alle drei kommen nie ins Repo, ohne sie bricht `tofu plan` ab.

Der Remote-State ist mit OpenTofu State Encryption (AES-GCM, PBKDF2) verschlüsselt, eine Passphrase je Stack. Lokal: `export TF_ENCRYPTION="$(cat ~/.homelab/tofu-encryption/<stack>.hcl)"`, in der CI die Secrets `TF_ENCRYPTION_CLUSTER`, `TF_ENCRYPTION_NETBIRD`, `TF_ENCRYPTION_UPTIME_KUMA`, `TF_ENCRYPTION_HARBOR` und `TF_ENCRYPTION_STATE`. Ohne Schlüssel lässt sich der State nicht lesen, die Passphrasen gehören zusätzlich in den Passwortmanager.

Jeder Stack läuft aus seinem Ordner. `netbird`, `uptime-kuma`, `harbor` und `state` wendet die CI nach dem Merge an, `cluster` die CI mit Freigabe. Der Cluster-Stack immer mit `tofu apply -parallelism=1`.
