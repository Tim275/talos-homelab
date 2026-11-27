# Secrets

Alle Schlüssel liegen im KV-Speicher `kv` (v2) in OpenBao, sortiert nach Nutzergruppe. Jede Gruppe hat einen eigenen ClusterSecretStore mit eigener OpenBao-Rolle, die nur ihren Ordner sieht.

```
kv/platform/<komponente>/<schlüssel>   Store openbao             Rolle eso-platform-namespace
kv/tenants/drova/<schlüssel>           Store openbao-tenants     Rolle eso-tenants
kv/customers/<namespace>/<schlüssel>   Store openbao-customers   Rolle eso-customer-namespace
```

- Der Ordner heißt wie die Komponente im Repo, die den Schlüssel braucht (`platform/harbor/…`, `platform/kube-prometheus-stack/…`), nicht wie ihr Namespace. Keine Umgebung im Pfad, jede Umgebung hat ihr eigenes OpenBao.
- Was ein Tenant liest, liegt unter `tenants/`, auch wenn die Plattform es schreibt (Datenbank-Passwort, Keycloak-Client, Harbor-Pull).
- Unter `platform/` hat jeder Plattform-Namespace eine eigene Identität: ESO meldet sich mit dem ServiceAccount `eso` des Namespaces an, die Policy `eso-ns-<namespace>` nennt nur dessen Pfade. Ein neuer Namespace braucht den ServiceAccount `eso` und einen Eintrag in `openbao-config/base/platform-namespaces.yaml`.
- Unter `customers/` sieht jeder Kunden-Namespace nur seinen eigenen Ordner. ESO meldet sich dort mit dem ServiceAccount `eso` des Namespaces an, die Policy setzt den Namespace aus dem Token in den Pfad ein. Nur `postgres`, das die Datenbank-Passwörter aller Kunden schreibt, nutzt `openbao-customers-platform` mit Zugriff auf ganz `customers/`.
- `openbao-tenants` ist nur für drova, drova-staging und die Plattform-Namespaces freigegeben, die für drova schreiben oder lesen (postgres, grafana, keycloak, harbor, kyverno). `openbao` ist für drova- und Kunden-Namespaces gesperrt.
- Werte, die kein Generator erzeugt (API-Tokens, Webhooks), trägt ein Mensch einmal in OpenBao ein, mit dem Wert direkt aus der Konsole des Anbieters. Danach kommen sie mit jedem Restore aus dem Snapshot zurück.

## Zugriff

- Oberfläche: `https://openbao.timourhomelab.org` (nur über VPN), Method **OIDC**, Rolle `admin`. Zugelassen ist die Keycloak-Gruppe `cluster-admins`, das Token gilt eine Stunde. Mit der Method LDAP scheitert jeder Login mit `permission denied`, eingerichtet ist nur OIDC.
- Direkt am Dienst, am Gateway vorbei: `kubectl -n openbao port-forward svc/openbao-active 18200:8200`, dann `BAO_ADDR=https://127.0.0.1:18200 BAO_SKIP_VERIFY=true bao status`.
- OpenBao entsiegelt sich selbst. Seal `static` mit dem Schlüssel aus dem Secret `openbao-seal-key`, das External Secrets über den Store `openbao-central-seal` aus dem zentralen Tresor holt, kein Cloud-KMS. Ein Recovery-Key (1 von 1), er liegt im Passwort-Manager.
- Ein Eintrag endgültig löschen: Oberfläche, Secret öffnen, Delete, **Destroy all versions**. „Delete this version“ lässt sich rückgängig machen, „Destroy this version“ lässt einen leeren Eintrag stehen.
- `PUT`, `PATCH` und `DELETE` lässt die WAF am Gateway nur für Hosts mit Ausnahme in `coraza-waf.yaml` durch, für OpenBao gilt die Regel 1100025. Ein leeres 403 kommt von der WAF, `{"errors":["permission denied"]}` von OpenBao, siehe [403 ohne Inhalt](network.md#403-ohne-inhalt).

## Neuer Schlüssel

1. Pfad nach der Regel oben wählen.
2. Zufallswerte per PushSecret mit ClusterGenerator `password` und `updatePolicy: IfNotExists`. Feste Werte in der Oberfläche unter `kv/platform/<komponente>/<secret>` eintragen, oder per CLI über die Eingabe: `bao kv put -mount=kv platform/<komponente>/<secret> <feld>=-`.
3. ExternalSecret mit dem Store der Gruppe.

## ExternalSecret oder PushSecret nicht synchron

```bash
kubectl get externalsecret,pushsecret -A | grep -v -E "SecretSynced|Synced"
kubectl -n <ns> describe externalsecret <name>
kubectl -n external-secrets logs deploy/external-secrets --since=10m | grep <name>
```

- `permission denied` → Pfad liegt außerhalb des Ordners der Rolle, falscher Store.
- `could not get secret data from provider` ohne weitere Meldung → Namespace ist für den Store nicht freigegeben (`conditions` am ClusterSecretStore) oder der Schlüssel fehlt.
- Store selbst prüfen: `kubectl get clustersecretstore` muss `Valid` zeigen.

## Zentraler Tresor

OpenBao außerhalb von Kubernetes, Container 1060 auf msa2, `https://192.168.0.60:8200` (Zertifikat auch für `bao.timourhomelab.org`). Er hält die festen Werte je Umgebung unter `kv/<umgebung>/platform/…`. Im prod-Cluster liest External Secrets sie über den Store `openbao-central` und schreibt sie per `pushsecret-bootstrap-values` in den Cluster-Tresor. Jeder Cluster meldet sich an seinem eigenen Mount `k8s-<umgebung>` an und liest nur seine Umgebung.

```bash
ssh root@192.168.0.50
pct exec 1060 -- bash
export BAO_ADDR=https://127.0.0.1:8200 BAO_CACERT=/opt/openbao/tls/ca.crt BAO_TLS_SERVER_NAME=bao.timourhomelab.org
bao status
bao login -method=userpass username=timour
```

- Nach einem Neustart von msa2 ist er versiegelt: `bao operator unseal`, Schlüssel aus dem Passwort-Manager. Laufende Cluster arbeiten weiter, nur neue oder geänderte Werte kommen nicht an.
- Neuer oder geänderter Wert: in der Oberfläche oder per `bao kv put -mount=kv prod/platform/<komponente>/<secret> <feld>=-`, für einen neuen Schlüssel zusätzlich ein Eintrag in `overlays/prod/central-openbao.yaml` und `pushsecret-bootstrap-values.yaml`.
- Neue Umgebung: `STAGE=staging ISSUER=<issuer des clusters> bash central-openbao-config.sh` mit den öffentlichen Schlüsseln dieses Clusters, siehe Kopf des Skripts.
- Sicherung täglich 01:45 nach Azure (`openbao-backups/central/`, mit `SHA256SUMS`), Alarm `CentralOpenBaoBackupStale`. Zurückspielen: Container mit `central-openbao.sh` neu aufbauen, Snapshot holen, `bao operator raft snapshot restore -force <datei>`, entsiegeln mit dem alten Schlüssel.
- Einrichtung: `tofu/stacks/proxmox/install/central-openbao*.sh`; die Skripte nutzen `BAO_TOKEN` aus dem Admin-Login.

## Neuaufbau

1. Workflow `tofu-root-cd` von Hand starten, Plan lesen, Umgebung `tofu-apply` freigeben.
2. Workflow `cluster-bootstrap` mit `apply` starten und freigeben: CRDs, Argo CD, root. Ohne `apply` ist es ein Trockenlauf.
3. Argo CD rollt aus; External Secrets holt Seal-Key und feste Werte aus dem zentralen Tresor.
4. `OpenBaoRestore` anlegen, damit generierte Passwörter aus dem Snapshot zurückkommen.

Beide Workflows laufen auf dem Runner `bootstrap` (Container 1061 auf msa2) und holen ihre Secrets per ID-Token aus `kv/prod/pipeline/cluster`. Schritt 3 klappt nur, wenn die Talos-Geheimnisse den Neuaufbau überleben, sonst kennt der zentrale Tresor die Schlüssel des neuen Clusters nicht.

