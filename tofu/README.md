# OpenTofu

## Stacks
One root module per state, each runs from its own folder. `modules/` holds the building blocks (`talos`, `openbao`, `rook-external`).

```
cluster      Proxmox VMs, Talos, OpenBao seed
proxmox      hosts, storages, tokens (local only, needs root@pam)
netbird
uptime-kuma
harbor       projects, robots, garbage collection
state        the Azure backend itself
```

```bash
cd tofu/stacks/<stack>
tofu init
tofu plan
```

## Cluster stack
Three files stay out of the repo, `tofu plan` fails without them:
```bash
ls tofu/stacks/cluster/openbao_values.auto.tfvars tofu/stacks/cluster/keys/seal.key tofu/stacks/cluster/rook_external.auto.tfvars
mise run pve-rook-export
tofu apply -parallelism=1
```
`pve-rook-export` writes `rook_external.auto.tfvars`.

## State encryption
The remote state is encrypted with OpenTofu State Encryption (AES-GCM, PBKDF2), one passphrase per stack. Keep the passphrases in the password manager too.
```bash
export TF_ENCRYPTION="$(cat ~/.homelab/tofu-encryption/<stack>.hcl)"
```
CI reads `TF_ENCRYPTION_CLUSTER`, `TF_ENCRYPTION_NETBIRD`, `TF_ENCRYPTION_UPTIME_KUMA`, `TF_ENCRYPTION_HARBOR` and `TF_ENCRYPTION_STATE`.

## CI
`netbird`, `uptime-kuma` and `harbor` are applied after the merge (`tofu-cd`), `cluster` by `tofu-root-cd`. Every apply waits for approval in the GitHub environment `tofu-apply`. `state` is only planned, apply it by hand.

Plan and drift sign in with an Azure app that can only read the state, so they run with `-lock=false`. Apply uses its own app that can only sign in from the environment `tofu-apply` (secret `AZURE_APPLY_CLIENT_ID`).

## Drift
Every day at 06:00 UTC `tofu-drift` plans `netbird`, `state`, `uptime-kuma`, `harbor` and `cluster`. `proxmox` is left out, it needs root@pam.
```bash
gh workflow run tofu-drift.yml
```

## OpenTofu version
1.13.9, in `mise.toml` and as `TOFU_VERSION` in the workflows. The downloads verify the SHA256 sum.

## State storage
`stacks/state` deletes old state versions after 30 days, locks the storage account against deletion (lock `state`) and allows no access with storage keys. Remove the lock before deleting or replacing it:
```bash
az lock delete --name state --resource-group rg-tofu-state --resource-name tofustatehomelab --resource-type Microsoft.Storage/storageAccounts
```
