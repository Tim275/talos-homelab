# netbird

NetBird-Cloud als Code. Apply läuft über `tofu-cd.yml` nach dem Merge, lokal nur `tofu plan`
mit `TF_VAR_netbird_api_token` (Secret `netbird/netbird-mgmt-api-key`).

Erlaubte Ports je Ziel: `lan_targets` in `variables.tofu`.
Neuer Routing-Peer: Einmal-Key im Dashboard, dann `netbird up --setup-key <key>`.
