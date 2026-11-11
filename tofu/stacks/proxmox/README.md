# proxmox

Proxmox-Hosts als Code: Installation per Antwortdatei, Cluster per mise, Storages und
API-Zugänge per tofu. Läuft nur lokal mit root@pam, nicht in CI.

## Neuaufbau

1. Bestandsaufnahme der alten Hosts: `ip -br link`, `ip -br a show vmbr0`, `lsblk -d -o NAME,MODEL`.
   NIC, Netzmaske und Platten-Filter mit `install/<host>.toml` abgleichen.
2. Sichern: `tofu state pull > ~/talos-homelab.tfstate.bak` in `tofu/stacks/cluster/`, Sealed-Secrets-Key, `tofu/stacks/cluster/keys/`,
   `tofu/stacks/cluster/openbao_values.auto.tfvars`.
3. `openssl passwd -6 > tofu/stacks/proxmox/install/root-password.hash`, dann je Host
   `mise run pve-iso <host>`, ISO auf USB, booten. Installation läuft ohne Eingabe, nach
   `first-boot.sh` startet der Host einmal neu. Prüfen: `grep nvme_core /proc/cmdline`,
   `sshd -T | grep passwordauth` (no), `ss -lntu | grep :111` (leer), `/var/log/first-boot.log`.
4. `ssh-keygen -R <ip>` für alle Hosts, dann `mise run pve-cluster`. Der Installer löscht nur die
   Boot-Platte, Platten mit altem Pool vor der Wiederverwendung leeren (`wipefs -a <disk>`).
5. Hier: `export PROXMOX_VE_USERNAME=root@pam; read -rs PROXMOX_VE_PASSWORD; export PROXMOX_VE_PASSWORD`,
   dann `tofu init && tofu apply`.
   `tofu output -raw talos_token` → `proxmox_api_token` in `tofu/stacks/proxmox.auto.tfvars` und
   GitHub-Secret `PROXMOX_API_TOKEN`. `tofu output -raw monitoring_token_value` →
   `monitoring.pve-exporter-token.token_value` in `tofu/stacks/cluster/openbao_values.auto.tfvars`.
6. `tofu/`: alte Adressen aus dem State (`tofu state rm $(tofu state list)`), dann
   `tofu apply -parallelism=1` lokal. Der tofu-Runner läuft erst wieder im neuen Cluster.
7. `mise run bootstrap`, alte NetBird-Peers im Dashboard löschen, neu anmelden (`tofu/netbird/README.md`).
