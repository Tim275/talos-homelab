# cloudflare

Public DNS als Code: ein CNAME je Eintrag in `public_hosts` auf den cloudflared-Tunnel, optional der Apex,
dazu der Wildcard-A-Record auf die Envoy-LB-IP (DNS-only, nur aus LAN und VPN erreichbar).
Apply läuft über `tofu-cd.yml` nach dem Merge, lokal nur `tofu plan` mit `TF_VAR_cloudflare_api_token`
(Zone:DNS:Edit) und `zone_id` in `terraform.tfvars` (Vorlage `terraform.tfvars.example`).
Welche Hosts der Tunnel ausliefert, steht in `kubernetes/infrastructure/network/cloudflared/overlays/prod/config.yaml`,
beide Listen müssen zusammenpassen. Von Hand angelegte Records stehen in `imports.tofu`.
