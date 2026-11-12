# Neuaufbau des Clusters

Reihenfolge, wenn der Cluster neu entsteht (Proxmox-Neuaufbau, `tofu destroy` und `apply`).

## Vorher sichern

Was nur im Cluster liegt, ist danach weg: die RGW-Buckets (CNPG-Backups `cnpg-*-backup`, Velero `velero-*`), die OpenBao-Daten und das LLDAP-Volume.

- Keycloak-DB, n8n-Postgres, drova-Postgres: den letzten Barman-Backup-Satz aus dem RGW auf einen externen S3 kopieren. Ohne ihn starten die Datenbanken leer.
- LLDAP legt Benutzer und Gruppen per Bootstrap-Job neu an, Passwörter nicht. Entweder das PVC per Velero sichern oder danach Passwörter neu setzen.
- OpenBao braucht keinen Snapshot, solange jeder Wert entweder aus `openbao_values.auto.tfvars` oder aus einem Generator kommt (siehe Secrets).
- Lokal vorhanden: `tofu/stacks/cluster/keys/seal.key`, `openbao_values.auto.tfvars`, `proxmox.auto.tfvars`.
- `drova-prod` bringt seine Secrets als SealedSecrets aus `Tim275/drova-gitops` mit. Der Controller bekommt seine beiden Schlüssel aus OpenBao (`sealed-secrets.sealed-secrets-bootstrap-key*` in der tfvars); fehlen sie, bleiben die Secrets verschlüsselt.

## Aufbau

1. `tofu apply -parallelism=1` im Stack `cluster`: VMs, Talos, kubeconfig, dazu zwei Secrets im Cluster: `openbao-seal-key` (Namespace `openbao`) und `openbao-bootstrap-values` (Namespace `external-secrets`, Schlüssel sind die Zeilen der tfvars).
2. `mise run bootstrap`: Argo CD, Projekt `argocd`, root. HTTPRoute und ExternalSecrets der Argo-CD-Installation scheitern beim Apply, weil ihre CRDs fehlen; die App `argocd` legt sie später an.
3. Argo CD baut den Rest ohne Handgriff: `crds`, dann `infrastructure` (der openbao-operator initialisiert und entsiegelt OpenBao mit dem Seal-Key, external-secrets schiebt die Startwerte per PushSecret `openbao-bootstrap-values` nach OpenBao), dann `platform`. `apps` und `tenants` werden von Hand gesynct.

## Secrets

- Startwerte (Tokens, Webhooks, SMTP, API-Keys) kommen aus der tfvars. Ein Schlüssel heißt `namespace.secret.feld`, genau wie im PushSecret `openbao-bootstrap-values`. Ein Schlüssel, der dort nicht steht, wird nicht geschoben.
- Alles andere erzeugen Generatoren im Cluster (`ClusterGenerator password`, PushSecret mit `IfNotExists`): DB-Passwörter, OIDC-Client-Secrets, Cookie-Secrets, der n8n-Schlüssel. Ein frisches OpenBao bekommt frische Werte, Erzeuger und Verbraucher lesen denselben Wert.
- Folgen frischer Werte: n8n-Credentials kommen über den Import-Job aus `n8n-prod/n8n-workflow-creds` zurück, Keycloak-TOTP wird neu eingerichtet, wenn die Keycloak-DB nicht wiederhergestellt wird.

## Datenbanken wiederherstellen

Cluster-CR von `initdb` auf `recovery` mit dem externen ObjectStore umstellen, syncen, dann zurück. Nach der Recovery setzt CNPG das Passwort der Owner-Rolle aus dem Secret, der neu erzeugte Wert passt.

## Prüfen

```sh
kubectl get applications -n argocd | grep -v Synced
kubectl -n external-secrets get pushsecret openbao-bootstrap-values
kubectl get externalsecrets -A | grep -v SecretSynced
```
