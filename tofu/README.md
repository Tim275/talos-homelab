# tofu

- `stacks/`: ein Root-Modul je State. `cluster` (Proxmox-VMs, Talos, OpenBao-Seed), `proxmox` (Hosts, Storages, Tokens; nur lokal mit root@pam), `cloudflare`, `netbird`, `uptime-kuma`, `state` (das Azure-Backend selbst, State bleibt lokal).
- `modules/`: Bausteine, die nur aus den Stacks heraus benutzt werden (`talos`, `openbao`).

Lokal braucht der Cluster-Stack in `stacks/cluster` die Startwerte `openbao_values.auto.tfvars` und den Seal-Key `keys/seal.key`. Beide kommen nie ins Repo, ohne sie bricht `tofu plan` ab.

Jeder Stack läuft aus seinem Ordner. `cloudflare`, `netbird` und `uptime-kuma` wendet die CI nach dem Merge an, `cluster` die CI mit Freigabe, `state` nur von Hand. Der Cluster-Stack immer mit `tofu apply -parallelism=1`.
