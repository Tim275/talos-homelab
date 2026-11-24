# Kunden

Bestellungen liegen in `kubernetes/customers/<env>/`, die APIs kommen als Paket `crossplane-apis` (siehe `crossplane/README.md`).

```bash
kubectl get configuration,configurationrevision,functions
kubectl get customers,customernamespaces,n8ninstances,postgresdatabases
```

## Lebenszyklus

```
 create ──► aktiv ──cancel──► gekündigt ──30 Tage / delete──► gelöscht
              ▲                  │
              └──────resume──────┘
```

GitHub → Actions → `customer` → Run workflow: Aktion, Kundennummer (`k100`), Dienste (`n8n`), Adresse und E-Mail (nur bei `create` und `invite`).

- `create`: Bestellung, App, Login, Einladung.
- `cancel`: `spec.suspended: true` und `suspended-at` in der Bestellung. App, Routen, Client, DNS und Check verschwinden, Namespace, Datenbank, Schlüssel und Gruppe bleiben, Nutzer werden gesperrt.
- `resume`: macht `cancel` rückgängig, Nutzer werden entsperrt, die Daten sind wieder da.
- `delete`: wartet auf deine Freigabe (GitHub-Environment `customer-delete`, „Review deployments“ im Lauf), entfernt dann die Bestellung. Datenbank, Rolle, Schlüssel in OpenBao, Gruppe, Nutzer und DNS-Eintrag werden gelöscht.
- `customer-purge` läuft täglich (Cron 04:30 UTC, GitHub startet ihn oft Stunden später) und löscht Kunden, die seit 30 Tagen gekündigt sind. Seine PRs mergen sich selbst, sobald die Checks durch sind.
- Je Umgebung ein PR, geöffnet von der GitHub-App `crossplane-automatic`. staging merged sich selbst, prod von Hand. Danach die App `customers` in Argo CD syncen.
- Das Repo ist öffentlich. In eine Bestellung gehören nur Kundennummer, Host-Name und Dienste, keine echte E-Mail-Adresse und kein Klarname. Für echte Kunden die Bestellungen vorher in ein privates Repo legen, im öffentlichen Verlauf bleibt sonst alles sichtbar.

## Einladung

Mit einer E-Mail-Adresse legt der Job `access` (läuft auf dem Runner im Cluster) im Realm `customers` die Gruppe `<kunde>` und den Nutzer an und lässt Keycloak die Mail zum Einrichten von Passwort und TOTP schicken. Der Link gilt 72 Stunden.

- Der Job wartet bis zu 30 Minuten, bis `https://<adresse>-<dienst>.<domain>/healthz` antwortet. Ist prod bis dahin nicht gemergt und gesynct, den Workflow mit `invite` erneut starten. `invite` verschickt auch eine neue Mail, wenn der Link abgelaufen ist.
- `cancel` sperrt alle Nutzer der Gruppe und meldet sie ab, `resume` entsperrt sie, `delete` löscht sie. Gehört ein Nutzer noch zu einem anderen Kunden, wird er nur aus der Gruppe genommen.
- Die Adresse steht nur in der Workflow-Eingabe und in Keycloak, nicht im Repo.

```bash
kubectl -n keycloak logs job/keycloak-config-cli-customers   # gibt es nur 10 min nach einem Sync der App keycloak
kubectl -n keycloak get secret keycloak-customer-invite-client-secret
```

- `login as customer-invite failed` → Realm oder Client fehlt, Job `keycloak-config-cli-customers` prüfen.
- `client secret of customer-invite not readable` → RoleBinding `customer-invite-secret-reader` im Namespace `keycloak` nennt nicht das ServiceAccount der Runner.
- Mail kommt nicht an → Keycloak-Log nach `EmailException` durchsuchen, Zugang in `kv/platform/keycloak/keycloak-smtp`.

Schlüssel liegen unter `kv/customers/<kunde>/<dienst>/`, zum Beispiel `kv/customers/k100/n8n/postgres` und `kv/customers/k100/n8n/encryption-key`. Kunden-Namespaces lesen nur über den Store `openbao-customers`, dessen Rolle nur `kv/customers/*` sieht. Den Plattform-Store `openbao` können sie nicht benutzen.

## CustomerAppDown

Der Blackbox-Check `https://<adresse>-<dienst>.<domain>/healthz` eines zahlenden Kunden schlägt seit 5 Minuten fehl. Geprüft wird aus dem Cluster über das Gateway (CoreDNS leitet Kunden-Hosts intern dorthin), nicht über Cloudflare. Test-Kunden (`zz…`) lösen keinen Alarm aus.

```bash
kubectl -n n8n-<kunde> get pods,httproute,securitypolicy
kubectl describe n8ninstance <kunde>
curl -s -o /dev/null -w "%{http_code}\n" https://<adresse>-n8n.timourhomelab.org/healthz
```

- Pod nicht bereit → Logs und Datenbank wie unter „Customer bleibt nicht Ready“.
- Pod bereit, Check rot → Route nicht `Accepted` oder Gateway-Problem, [HomelabEdgeDown](network.md#homelabedgedown).
- Intern grün, Kunde meldet Ausfall → Tunnel oder Cloudflare, [CloudflaredNoEdgeConnections](network.md#cloudflarednoedgeconnections).

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
- `cannot initialize dependency graph … node … already exists` → zwei Functions oder Provider mit derselben Quelle. Der Resolver legt ein Duplikat `crossplane-contrib-<paket>` an, wenn die Configuration Abhängigkeiten selbst auflöst (crossplane#7880). Prüfen: `kubectl get configuration crossplane-apis -o jsonpath='{.spec.skipDependencyResolution}'` muss `true` sein (#450). Dann die Duplikate löschen (`kubectl get functions,providers`, alles mit Präfix `crossplane-contrib-` und ohne Argo-Tracking), nach etwa 2 min sind alle Pakete Healthy.
- Function-Versionen in `overlays/<env>/functions.yaml` müssen die Mindestversionen in `crossplane/crossplane.yaml` erfüllen; geprüft wird das wegen `skipDependencyResolution` nur noch per `crossplane render` in der CI.

## Löschen hängt

```bash
kubectl get ns n8n-<kunde> -o jsonpath='{.status.conditions[*].message}'
kubectl -n postgres get database,databaserole | grep <kunde>
```

- PushSecret hängt → Store darf den Schlüssel nicht löschen, Policy `eso-customers` bzw. `eso` prüfen.
- Datenbank bleibt → `kubectl -n postgres describe database n8n-<kunde>`, offene Verbindungen beenden.
