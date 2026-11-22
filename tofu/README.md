# tofu

- `stacks/`: ein Root-Modul je State. `cluster` (Proxmox-VMs, Talos, OpenBao-Seed), `proxmox` (Hosts, Storages, Tokens; nur lokal mit root@pam), `netbird`, `uptime-kuma`, `harbor` (Projekte, Robots, Garbage Collection), `state` (das Azure-Backend selbst).
- `modules/`: Bausteine, die nur aus den Stacks heraus benutzt werden (`talos`, `openbao`).

Lokal braucht der Cluster-Stack in `stacks/cluster` die Startwerte `openbao_values.auto.tfvars`, den Seal-Key `keys/seal.key` und die Ceph-Zugänge `rook_external.auto.tfvars` (`mise run pve-rook-export`). Alle drei kommen nie ins Repo, ohne sie bricht `tofu plan` ab.

Der Remote-State ist mit OpenTofu State Encryption (AES-GCM, PBKDF2) verschlüsselt, eine Passphrase je Stack. Lokal: `export TF_ENCRYPTION="$(cat ~/.homelab/tofu-encryption/<stack>.hcl)"`, in der CI die Secrets `TF_ENCRYPTION_CLUSTER`, `TF_ENCRYPTION_NETBIRD`, `TF_ENCRYPTION_UPTIME_KUMA`, `TF_ENCRYPTION_HARBOR` und `TF_ENCRYPTION_STATE`. Ohne Schlüssel lässt sich der State nicht lesen, die Passphrasen gehören zusätzlich in den Passwortmanager.

Jeder Stack läuft aus seinem Ordner. `netbird`, `uptime-kuma` und `harbor` wendet die CI nach dem Merge an, `cluster` die CI mit Freigabe, `state` plant die CI nur, Apply von Hand. Der Cluster-Stack immer mit `tofu apply -parallelism=1`.

Plan und Drift melden sich mit einer Azure-App an, die den State nur lesen darf. Apply läuft mit einer eigenen App, die nur aus dem GitHub-Environment `tofu-apply` anmelden kann (Secret `AZURE_APPLY_CLIENT_ID`). Deshalb laufen Plan und Drift mit `-lock=false`. `tofu-drift` plant täglich um 06:00 UTC `netbird`, `state`, `uptime-kuma`, `harbor` und `cluster`. `proxmox` fehlt, der Stack braucht root@pam.

OpenTofu 1.13.9 steht in `mise.toml` und als `TOFU_VERSION` in den Workflows, die Downloads prüfen die SHA256-Summe.

Der State-Speicher (`stacks/state`) löscht alte State-Versionen nach 30 Tagen, hat ein Lock gegen Löschen (`state` an der Resource Group `rg-tofu-state`) und keinen Zugriff per Speicherschlüssel. Zum Löschen oder Ersetzen zuerst das Lock entfernen.
