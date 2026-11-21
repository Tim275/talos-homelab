# Kunden

Bestellungen liegen in `kubernetes/customers/<env>/`, die APIs kommen als Paket `crossplane-apis` (siehe `crossplane/README.md`).

```bash
kubectl get configuration,configurationrevision,functions
kubectl get customers,customernamespaces,n8ninstances,postgresdatabases
```

## Bestellen und kündigen

GitHub → Actions → `customer` → Run workflow: `create`, `cancel` oder `invite`, Kundennummer (`k100`), Dienste (`n8n`), Adresse, E-Mail des Kunden.

- Je Umgebung ein PR. staging merged sich selbst, prod von Hand.
- Nach dem Merge die App `customers` in Argo CD syncen.
- Kündigen löscht Namespace und Instanz. Datenbank, Rolle und die Schlüssel in OpenBao bleiben.

## Einladung

Mit einer E-Mail-Adresse legt der Job `access` (läuft auf dem Runner im Cluster) im Realm `customers` die Gruppe `<kunde>` und den Nutzer an und lässt Keycloak die Mail zum Einrichten von Passwort und TOTP schicken. Der Link gilt 72 Stunden.

- Der Job wartet bis zu 30 Minuten, bis `https://<adresse>-<dienst>.<domain>/healthz` antwortet. Ist prod bis dahin nicht gemergt und gesynct, den Workflow mit `invite` erneut starten. `invite` verschickt auch eine neue Mail, wenn der Link abgelaufen ist.
- `cancel` sperrt alle Nutzer der Gruppe und meldet sie ab. Gruppe und Nutzer bleiben erhalten.
- Die Adresse steht nur in der Workflow-Eingabe und in Keycloak, nicht im Repo.

```bash
kubectl -n keycloak logs job/keycloak-config-cli-customers
kubectl -n keycloak get secret keycloak-customer-invite-client-secret
```

- `login as customer-invite failed` → Realm oder Client fehlt, Job `keycloak-config-cli-customers` prüfen.
- `client secret of customer-invite not readable` → RoleBinding `customer-invite-secret-reader` im Namespace `keycloak` nennt nicht das ServiceAccount der Runner.
- Mail kommt nicht an → Keycloak-Log nach `EmailException` durchsuchen, Zugang in `kv/platform/keycloak/keycloak-smtp`.

Schlüssel liegen unter `kv/customers/<kunde>/<dienst>/`, zum Beispiel `kv/customers/k100/n8n/postgres` und `kv/customers/k100/n8n/encryption-key`. Kunden-Namespaces lesen nur über den Store `openbao-customers`, dessen Rolle nur `kv/customers/*` sieht. Den Plattform-Store `openbao` können sie nicht benutzen.

## Kunde kommt nicht an seine App

Weg: Cloudflare → Tunnel → Gateway → Login auf `login.<domain>` (Realm `customers`) → App. `/webhook/` und `/form/` gehen ohne Login.

```bash
kubectl -n n8n-<kunde> get securitypolicy,httproute,dnsendpoint,client.openidclient.keycloak.m.crossplane.io
kubectl -n crossplane-system get group.group.keycloak.m.crossplane.io <kunde>
dig +short <adresse>-n8n.<domain>
```

- Name löst nicht auf → DNSEndpoint fehlt oder external-dns schreibt nicht: `kubectl -n external-dns logs deploy/external-dns | grep <adresse>`.
- 403 nach dem Login → Nutzer ist nicht in der Gruppe `<kunde>`, Workflow mit `invite` erneut starten.
- Login-Seite meldet „Invalid redirect uri“ → Client `n8n-<kunde>` nicht `Synced`, `kubectl describe` am Client, Zugang des Providers in `crossplane-system/keycloak-provider-credentials`.

## Customer bleibt nicht Ready

```bash
kubectl describe customer <kunde>
kubectl describe n8ninstance <kunde>
kubectl describe postgresdatabase n8n-<kunde>
kubectl -n crossplane-system logs deploy/crossplane --tail 100 | grep -i <kunde>
```

- `cannot render`/`fatal` → Vorlage kaputt, letzte Paketversion in `overlays/<env>/configuration.yaml` zurücknehmen.
- `forbidden` → ClusterRole in `kubernetes/platform/automation/crossplane/base/rbac-*.yaml` fehlt das Kind.
- Datenbank `applied` bleibt aus → `kubectl -n postgres describe database n8n-<kunde>`, [CnpgPrimaryDown](data.md#cnpgprimarydown).
- n8n startet nicht → `kubectl -n n8n-<kunde> logs deploy/n8n`, Secret `n8n-<kunde>-postgres` vorhanden?
- Pod wird nicht angelegt → `kubectl -n n8n-<kunde> get events`: `exceeded quota` (Quota im `CustomerNamespace` anheben) oder `violates PodSecurity` (Pod erfüllt `restricted` nicht).
- Verbindung bricht ab → Default-deny im Namespace: `kubectl -n n8n-<kunde> get ciliumnetworkpolicy default-deny -o yaml`, Drops mit `hubble observe --namespace n8n-<kunde> --verdict DROPPED`.

## Paket nicht Healthy

```bash
kubectl describe configuration crossplane-apis
kubectl describe configurationrevision
```

- Pull-Fehler → `ghcr.io/tim275/talos-homelab/crossplane-apis` erreichbar und öffentlich?
- `incompatible dependencies` → Function-Version in `overlays/<env>/functions.yaml` liegt unter der Mindestversion in `crossplane/crossplane.yaml`.

## Daten endgültig löschen

Erst nach der Kündigung und nur, wenn die Daten weg dürfen.

```bash
primary=$(kubectl -n postgres get pod -l cnpg.io/instanceRole=primary -o name)
kubectl -n postgres exec -it "$primary" -c postgres -- psql -c 'DROP DATABASE n8n_<kunde>' -c 'DROP ROLE n8n_<kunde>'
```

In OpenBao den Ordner `kv/customers/<kunde>/` löschen, darin liegen alle Schlüssel des Kunden.
