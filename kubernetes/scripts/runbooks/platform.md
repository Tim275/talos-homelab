# Plattform

## KeycloakDown

Keine Keycloak-Replica ready. OIDC-Login ist clusterweit kaputt: ArgoCD, Grafana, n8n, kubectl.

```bash
kubectl -n keycloak get pods -l app=keycloak -o wide
kubectl -n keycloak describe pod <pod> | grep -A5 -E "Last State|Events"
kubectl -n keycloak logs <pod> --previous --tail 80
kubectl cnpg status keycloak-db -n keycloak
```

- `OOMKilled` → Memory-Limit gegen den echten Verbrauch prüfen.
- `ImagePullBackOff` → Registry (quay.io) gestört, dagegen hilft nur Warten.
- keycloak-db nicht bereit → [CnpgPrimaryDown](data.md#cnpgprimarydown)
- kubectl ohne OIDC: `talosctl -n 192.168.0.101 kubeconfig`

## KeycloakBurnRateFast

Keycloak läuft, aber zu viele Anfragen enden mit 5xx. Das Fehlerbudget (99,5 % über 30 Tage) ist in rund zwei Tagen weg. Logins scheitern.

```bash
kubectl -n keycloak logs -l app=keycloak --tail 200 | grep -iE "error|exception" | tail -20
kubectl cnpg status keycloak-db -n keycloak
```

- DB-Verbindungsfehler im Log → Datenbank, nicht Keycloak.
- Fehler nur beim LDAP-Login → LLDAP prüfen: `kubectl -n lldap get pods`

## N8NBurnRateFast

n8n.timourhomelab.org antwortet nicht mehr zuverlässig. Gemessen wird mit der Blackbox-Probe (alle 30 s), weil n8n kaum echte Anfragen hat. Gilt auch für N8NBurnRateSlow und N8NBurnRateTicket.

```bash
kubectl -n n8n-prod get pod
kubectl -n n8n-prod logs deploy/n8n-main --tail 100
kubectl cnpg status n8n-postgres -n n8n-prod
```

- n8n-main läuft, Probe scheitert trotzdem → HTTPRoute und Envoy Gateway prüfen: `kubectl -n n8n-prod get httproute`
- Probe läuft im Cluster: sie sieht den Weg über Cloudflare nicht.

## ArgoCDAppsMassDeletion

Die Zahl der ArgoCD-Apps ist in 30 min um mehr als 20 % gefallen. ApplicationSet gelöscht, Generator leer oder Kaskaden-Prune.

```bash
kubectl -n argocd get applicationsets
kubectl -n argocd get applications --no-headers | wc -l
kubectl -n argocd logs deploy/argocd-applicationset-controller --tail 100 | grep -iE "delet|error"
git log --oneline -10 -- kubernetes/applicationsets/
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

## SealedSecretsCertExpiresIn14Days

Das Verschlüsselungszertifikat von sealed-secrets läuft in weniger als 14 Tagen ab. Danach kann niemand mehr neue Secrets versiegeln, Entschlüsseln geht weiter.

```bash
kubectl -n sealed-secrets get secret -l sealedsecrets.bitnami.com/sealed-secrets-key
openssl x509 -in tofu/bootstrap/sealed-secrets/certificate/sealed-secrets-2026.crt -noout -enddate
```

- Neues Schlüsselpaar in `tofu/bootstrap/sealed-secrets/` als zusätzlichen aktiven Key anlegen, Controller neu starten, Secrets neu versiegeln, dann das Datum in der Regel nachziehen.
- Den alten Key nicht löschen, er entschlüsselt die bestehenden SealedSecrets.
- Nicht mit einem abgelaufenen `.crt` versiegeln, kubeseal lehnt das ab.

## LogsSealedSecretsDecryptFailure

Der Controller kann SealedSecrets nicht entschlüsseln. Betrifft potenziell jedes Secret im Cluster.

```bash
kubectl -n sealed-secrets logs deploy/sealed-secrets-controller --since=15m | grep -iE "decrypt|unseal"
kubectl get sealedsecrets -A | grep -v True
```

- Einzelnes SealedSecret mit `no key could decrypt` → wurde mit einem Key versiegelt, der nicht mehr im Ring ist. Mit dem aktuellen Zertifikat neu versiegeln:
  ```bash
  kubectl create secret generic <name> -n <ns> --from-literal=k=v --dry-run=client -o yaml \
    | kubeseal --cert tofu/bootstrap/sealed-secrets/certificate/sealed-secrets-2026.crt --format yaml --scope strict
  ```
- Alle SealedSecrets betroffen → Key-Secrets im Namespace fehlen. Nur dieses Modul anwenden, nicht den ganzen Root-Plan (der fasst sonst die Machine-Config aller Nodes an):
  ```bash
  cd tofu && tofu apply -target=module.sealed-secrets -parallelism=1
  ```

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

- 401/403 → Token/Webhook ungültig. Neu versiegeln (siehe [LogsSealedSecretsDecryptFailure](#logssealedsecretsdecryptfailure)), Secret-Namen stehen in `alertmanager.alertmanagerSpec.secrets`.
- Eine Config-Änderung wirkt nicht: der Operator kann sie abgelehnt haben, der Pod läuft dann still mit der alten Config weiter.
  ```bash
  kubectl -n monitoring get alertmanager kube-prometheus-stack-alertmanager -o jsonpath='{.status.conditions}'
  ```
