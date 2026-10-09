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

Manuell und lokal, vorher immer den Plan ansehen:

```bash
cd tofu/netbird
export TF_VAR_netbird_api_token=<aus Secret netbird/netbird-mgmt-api-key>
tofu plan
tofu apply
```

Danach vom Mac aus prüfen, dass die Ziele erreichbar sind.

## Routing-Peer hinzufügen

Setup-Key im Dashboard anlegen (einmalig, Limit 1, Auto-Gruppe `homelab-routers`),
auf dem Host `netbird up --setup-key <key>`. Peer-Approval ist an.
