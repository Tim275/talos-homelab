# Secrets

Alle Schlüssel liegen im KV-Speicher `kv` (v2) in OpenBao, sortiert nach Nutzergruppe. Jede Gruppe hat einen eigenen ClusterSecretStore mit eigener OpenBao-Rolle, die nur ihren Ordner sieht.

```
kv/platform/<komponente>/<schlüssel>   Store openbao             Rolle eso
kv/tenants/drova/<schlüssel>           Store openbao-tenants     Rolle eso-tenants
kv/customers/<kunde>/<dienst>/…        Store openbao-customers   Rolle eso-customers
```

- Der Ordner heißt wie die Komponente im Repo, die den Schlüssel braucht (`platform/harbor/…`, `platform/kube-prometheus-stack/…`), nicht wie ihr Namespace. Keine Umgebung im Pfad, jede Umgebung hat ihr eigenes OpenBao.
- Was ein Tenant liest, liegt unter `tenants/`, auch wenn die Plattform es schreibt (Datenbank-Passwort, Keycloak-Client, Harbor-Pull).
- `openbao-tenants` ist nur für drova, drova-staging und die Plattform-Namespaces freigegeben, die für drova schreiben oder lesen (postgres, grafana, keycloak, harbor, kyverno). `openbao` ist für drova- und Kunden-Namespaces gesperrt.
- Werte, die kein Generator erzeugt (API-Tokens, Webhooks), kommen beim Aufbau aus `tofu/stacks/cluster/openbao_values.auto.tfvars` und werden von `pushsecret-bootstrap-values` geschrieben.

## Zugriff

- Oberfläche: `https://openbao.timourhomelab.org` (nur über VPN), Method **OIDC**, Rolle `admin`. Zugelassen ist die Keycloak-Gruppe `cluster-admins`, das Token gilt eine Stunde. Mit der Method LDAP scheitert jeder Login mit `permission denied`, eingerichtet ist nur OIDC.
- Direkt am Dienst, am Gateway vorbei: `kubectl -n openbao port-forward svc/openbao-active 18200:8200`, dann `BAO_ADDR=https://127.0.0.1:18200 BAO_SKIP_VERIFY=true bao status`.
- OpenBao entsiegelt sich selbst. Seal `static` mit dem Schlüssel aus dem Secret `openbao-seal-key` (`keys/seal.key`, von tofu angelegt), kein Cloud-KMS. Die Recovery-Keys sind per Shamir geteilt.
- Ein Eintrag endgültig löschen: Oberfläche, Secret öffnen, Delete, **Destroy all versions**. „Delete this version“ lässt sich rückgängig machen, „Destroy this version“ lässt einen leeren Eintrag stehen.
- `PUT`, `PATCH` und `DELETE` lässt die WAF am Gateway nur für Hosts mit Ausnahme in `coraza-waf.yaml` durch, für OpenBao gilt die Regel 1100025. Ein leeres 403 kommt von der WAF, `{"errors":["permission denied"]}` von OpenBao, siehe [403 ohne Inhalt](network.md#403-ohne-inhalt).

## Neuer Schlüssel

1. Pfad nach der Regel oben wählen.
2. Zufallswerte per PushSecret mit ClusterGenerator `password` und `updatePolicy: IfNotExists`, feste Werte in `openbao_values.auto.tfvars` und `pushsecret-bootstrap-values.yaml`.
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
