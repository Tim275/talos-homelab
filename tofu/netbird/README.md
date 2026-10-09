# tofu/netbird

NetBird-Cloud-Konfiguration als Code: Gruppen, Netzwerk mit Ressourcen und Router,
Policies, Posture-Check und Account-Einstellungen. Eigener State (`netbird.tfstate`),
unabhängig vom Cluster.

Nicht enthalten: Peers, Setup-Keys, Clients, der Routing-Peer-Install auf den Proxmox-Hosts.

## Zugriff

`lan_targets` in `variables.tofu` nennt jedes Ziel mit Adresse und erlaubten TCP-Ports.
Je Port-Gruppe gibt es eine Policy `homelab-users-to-lan-<ports>`. `homelab-users-to-routers`
erlaubt 22 und 8006 auf den Routing-Peers.

## Apply

Über `tofu-cd.yml`: Der PR zeigt den Plan als Kommentar, nach dem Merge wendet der
Workflow ihn an (Environment `tofu-apply`, mit Freigabe). Lokal nur zum Planen:

```bash
cd tofu/netbird
export TF_VAR_netbird_api_token=<aus Secret netbird/netbird-mgmt-api-key>
tofu plan
```

Nach dem Apply vom Mac aus prüfen, dass die Ziele erreichbar sind.

## Routing-Peer hinzufügen

Setup-Key im Dashboard anlegen (einmalig, Limit 1, Auto-Gruppe `homelab-routers`),
auf dem Host `netbird up --setup-key <key>`. Peer-Approval ist an.
