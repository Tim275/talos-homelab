# Plattform

## KeycloakDown

Keine Keycloak-Replica ready. OIDC-Login ist clusterweit kaputt: ArgoCD, Grafana, n8n, kubectl.

```bash
kubectl -n keycloak get pods -l app=keycloak -o wide
kubectl -n keycloak describe pod <pod> | grep -A5 -E "Last State|Events"
kubectl -n keycloak logs <pod> --previous --tail 80
kubectl cnpg status postgres -n postgres
```

- `OOMKilled` → Memory-Limit gegen den echten Verbrauch prüfen.
- `ImagePullBackOff` → Registry (quay.io) gestört, dagegen hilft nur Warten.
- Datenbank nicht bereit → [CnpgPrimaryDown](data.md#cnpgprimarydown)
- kubectl ohne OIDC: `talosctl -n 192.168.0.101 kubeconfig`

## KeycloakBurnRateFast

Keycloak läuft, aber zu viele Anfragen enden mit 5xx. Das Fehlerbudget (99,5 % über 28 Tage) ist in rund zwei Tagen weg. Logins scheitern.

```bash
kubectl -n keycloak logs -l app=keycloak --tail 200 | grep -iE "error|exception" | tail -20
kubectl cnpg status postgres -n postgres
```

- DB-Verbindungsfehler im Log → Datenbank, nicht Keycloak.
- Fehler nur beim LDAP-Login → LLDAP prüfen: `kubectl -n lldap get pods`
- Langsame Logins → Grafana „Keycloak troubleshooting“ (Ordner Security), Traces in Tempo mit `service.name=keycloak`.

## Keycloak-Upgrade

Renovate mergt Keycloak nie selbst. Patch-Versionen rollen Pod für Pod, Minor und Major starten alle Pods neu (Update-Strategie `Auto` entscheidet). Die Datenbank lässt sich nicht zurückmigrieren, ein Rollback ist nur ein Restore.

Vor dem Merge eines Minor- oder Major-Updates:

```bash
kubectl cnpg backup postgres -n postgres --method plugin --plugin-name barman-cloud.cloudnative-pg.io
kubectl -n postgres get backup --sort-by=.metadata.creationTimestamp | tail -1
```

Erst mergen, wenn das Backup `completed` ist. Danach:

```bash
kubectl -n keycloak get keycloaks.k8s.keycloak.org keycloak -o jsonpath='{.status.conditions}'
kubectl -n keycloak get pods -l app=keycloak
```

- Operator (`keycloak-operator/overlays/<env>/kustomization.yaml`) und Server-Image (`keycloak/overlays/<env>/images.yaml`) tragen dieselbe Version. Keycloak-Doku: „A single Operator version supports a single matching Keycloak version.“ Renovate gruppiert beide als `keycloak`. Kommt ein Teil später, den PR nicht liegen lassen. Der Server lief schon einmal mit 26.8.2 vor dem Operator auf 26.8.1, ohne Folgen.
- Der Rollout am 20.11. (drei Instanzen, Pods nacheinander neu gestartet) lief ohne 5xx am Gateway. Davor gab es zwei Ausfälle mit 503: am 15.11. (Ursache nicht belegt, keine Logs mehr) und am 19.11. beim Neustart der Pods.
- Keycloak läuft über den PgBouncer im Transaktionsmodus. Das geht nur mit PgBouncer ab 1.21 und `max_prepared_statements` > 0 (Pooler `postgres-pooler`).

## N8NBurnRateFast

n8n.timourhomelab.org antwortet nicht mehr zuverlässig. Gemessen wird mit der Blackbox-Probe (alle 30 s), weil n8n kaum echte Anfragen hat. Gilt auch für N8NBurnRateSlow und N8NBurnRateTicket.

```bash
kubectl -n n8n get pod
kubectl -n n8n logs deploy/n8n-main --tail 100
kubectl cnpg status postgres -n postgres
```

- n8n-main läuft, Probe scheitert trotzdem → HTTPRoute und Envoy Gateway prüfen: `kubectl -n n8n get httproute`
- Probe läuft im Cluster: sie sieht den Weg über Cloudflare nicht.

## ArgoCDAppsMassDeletion

Die Zahl der ArgoCD-Apps ist in 30 min um mehr als 20 % gefallen. ApplicationSet gelöscht, Generator leer oder Kaskaden-Prune.

```bash
kubectl -n argocd get applicationsets
kubectl -n argocd get applications --no-headers | wc -l
kubectl -n argocd logs deploy/argocd-applicationset-controller --tail 100 | grep -iE "delet|error"
git log --oneline -10 -- kubernetes/argocd/applicationsets/
```

- Weitere Löschungen stoppen, solange unklar ist, was passiert:
  ```bash
  kubectl -n argocd scale deploy argocd-applicationset-controller --replicas=0
  ```
- Alle ApplicationSets haben `preserveResourcesOnDeletion: true`. Gelöschte Apps lassen ihre Ressourcen stehen, die Workloads laufen weiter.
- Ursache im letzten Merge zurücknehmen, dann den Controller wieder hochskalieren.

## CertExpiringIn7Days

Ein Zertifikat läuft in weniger als 7 Tagen ab, cert-manager hat es nicht erneuert.

```bash
kubectl -n <ns> describe certificate <name>
kubectl -n <ns> get certificaterequest,order,challenge
kubectl -n cert-manager logs deploy/cert-manager --tail 100 | grep -i <name>
```

- Meist hängt die ACME-Challenge (DNS-Token, Rate-Limit). Erst die Ursache in Order/Challenge beheben.
- Danach neu ausstellen lassen: das TLS-Secret des Zertifikats löschen, cert-manager stellt dann sofort neu aus.

## LogsAuditAnonymousAccess

Jemand spricht den apiserver ohne Identität an. Baseline ist null.

```
{source="kube-audit"} | json | user_username="system:anonymous"
```
```bash
kubectl get clusterrolebindings,rolebindings -A -o wide | grep -i anonymous
```

- `sourceIPs` und `requestURI` im Audit-Log zeigen, wer und was.
- Binding auf `system:anonymous` gefunden → entfernen. Integrationstests (z. B. Rook) legen so etwas an und räumen nicht immer auf.

## PrometheusPodMissing

Weniger Prometheus-Pods ready als gewünscht. Mit einer Replica weniger sieht der Rest noch alles, ohne jede sind alle Alarme blind.

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=prometheus -o wide
kubectl -n monitoring describe pod <pod> | tail -20
```

- Pod in `Phase=Succeeded` nach einer Eviction: `kubectl -n monitoring delete pod <pod> --force`
- Pending → Node-Pool `stateful` voll oder PVC hängt.

## AlertmanagerPodMissing

Weniger Alertmanager-Pods ready als gewünscht. Ein toter Alertmanager fällt sonst nicht auf, weil die Mehrheit weiter zustellt.

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=alertmanager -o wide
kubectl -n monitoring delete pod <pod> --force
```

## AlertmanagerClusterFailedToSendAlerts

Alle Alertmanager scheitern an derselben Integration (Slack, Telegram, Jira, Webhook). Die Zustellung ist kaputt, das Secret dahinter meist auch.

```bash
kubectl -n monitoring logs alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager --since=30m | grep -i notify
```
```promql
sum by (integration, reason) (rate(alertmanager_notifications_failed_total[15m]))
```

- 401/403 → Token/Webhook ungültig. Wert in OpenBao prüfen, Secret-Namen stehen in `alertmanager.alertmanagerSpec.secrets`.
- Eine Config-Änderung wirkt nicht: der Operator kann sie abgelehnt haben, der Pod läuft dann still mit der alten Config weiter.
  ```bash
  kubectl -n monitoring get alertmanager kube-prometheus-stack-alertmanager -o jsonpath='{.status.conditions}'
  ```
- Jira `can't find transition` → `resolve_transition`/`reopen_transition` suchen den Transition-Namen exakt. Status im Projekt umbenannt oder Workflow getauscht → Namen neu setzen. Aktuelle Namen:
  ```bash
  curl -su "$USER:$TOKEN" https://timourmiagol.atlassian.net/rest/api/2/issue/SCRUM-1/transitions | jq -r '.transitions[].name'
  ```

## LokiIngestionOverloadDropping

Loki verwirft über 1 % der eingehenden Logzeilen, meist weil ein Stream das Limit sprengt. Die verworfenen Zeilen sind verloren.

```bash
kubectl -n monitoring logs loki-0 --since=30m | grep -iE "rate limit|stream limit" | tail -5
```

In Grafana (Loki) die lauteste Quelle: `topk(5, sum by (namespace, pod) (bytes_rate({namespace=~".+"}[5m])))`

- Log-Spam an der Quelle beheben (Log-Level, Schleife), nicht das Limit hochsetzen
- Limits: `ingestion_rate_mb` und `per_stream_rate_limit` in `kubernetes/platform/observability/loki/base/values.yaml`
