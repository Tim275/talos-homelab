# tofu/netbird — NetBird Control-Plane als Code (Phase 2)

Kodifiziert die NetBird-Cloud-Config (Netz · Resource · Router · Split-DNS · Policy ·
Setup-Key). **Eigener State** (`netbird.tfstate`) → voll isoliert vom Cluster, `tofu apply`
hier kann die Talos-VMs nie anfassen.

## Was es managed / NICHT managed
```
✅ NetBird-Control-Plane:  Netz, LAN-Resource, Router-Zuordnung, Split-DNS-Nameserver,
                           Access-Policy, reusable Setup-Key, Groups
❌ NICHT:  Routing-Peer-Install auf den Proxmox-Hosts  → Bash/cloud-init (siehe scripts/)
           Client auf Geräten (Mac/Handy)              → manuell / MDM
           der split-dns CoreDNS selbst                → GitOps (Phase 1, im Cluster)
```

## Voraussetzungen
1. **NetBird API-Token (PAT):** Dashboard → User (oben rechts) → Settings → API Keys → Create.
2. **split-dns IP:** erst nach Phase 1 (CoreDNS-Deploy im Cluster) bekannt → in `terraform.tfvars`.

## Apply
```bash
cd tofu/netbird
export TF_VAR_netbird_api_token="nbp_xxx"      # NIE committen
cp terraform.tfvars.example terraform.tfvars   # split_dns_ip eintragen
tofu init
tofu plan      # IMMER erst plan ansehen
tofu apply
```

## ⚠️ Reconciliation — das manuelle Setup von 2026-06-09
Netz/Policy/Peers wurden anfangs **manuell** im Dashboard erstellt. Dieses tofu erstellt
**neue** Resources → es würde ein ZWEITES "homelab"-Netz anlegen. Zwei Wege:

**A) Sauber neu (empfohlen für klare IaC):** im Dashboard das manuelle "homelab"-Netz +
Policy löschen → `tofu apply` legt alles frisch an → Routing-Peers mit dem neuen
`routing_peer_setup_key` **neu** verbinden:
```bash
tofu output -raw routing_peer_setup_key   # neuen Key holen
# auf msa2 + nipogi:  netbird up --setup-key <KEY>
```

**B) Import (Bestand behalten):** `tofu import netbird_network.homelab <network-id>` etc. —
mehr Aufwand, nur wenn du die laufenden Peers nicht neu-keyen willst.

## Peers anbinden (nach Apply)
Setup-Key ist im Output (sensitive). Routing-Peer-Install: siehe `notes/CLAUDE-NETBIRD.md` §2.

## Cloud vs Self-Hosted
Gleicher Code — nur `netbird_management_url` ändern (Cloud-Default = api.netbird.io).
