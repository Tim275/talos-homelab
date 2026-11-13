# tofu

- `stacks/`: ein Root-Modul je State. `cluster` (Proxmox-VMs, Talos, OpenBao-Seed, CSI), `proxmox` (Hosts, Storages, Tokens; nur lokal mit root@pam), `cloudflare`, `netbird`, `uptime-kuma`, `state` (das Azure-Backend selbst, State bleibt lokal).
- `modules/`: Bausteine, die nur aus den Stacks heraus benutzt werden (`talos`, `openbao`, `proxmox-csi-plugin`).

Die OpenBao-Startwerte (`openbao_bootstrap_values`) liest der Cluster-Stack aus einer lokalen `openbao_values.auto.tfvars` in `stacks/cluster`, die nie ins Repo kommt.

Jeder Stack läuft aus seinem Ordner. `cloudflare`, `netbird` und `uptime-kuma` wendet die CI nach dem Merge an, `cluster` die CI mit Freigabe, `state` nur von Hand. Der Cluster-Stack immer mit `tofu apply -parallelism=1`.
