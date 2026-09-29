# Drova

SLOs je Dienst über 30 Tage: 99,5 % Verfügbarkeit, 99 % der Anfragen unter 500 ms. Fast Burn = Budget wird 14,4× so schnell verbraucht, auf dem 5-min- und dem 1-h-Fenster gleichzeitig. Das Monatsbudget ist dann in rund zwei Tagen weg.

Dashboard: https://grafana.timourhomelab.org/d/drova-service-detail
Deployt wird aus `Tim275/drova-gitops` (`overlays/production`) über die ArgoCD-App `drova-prod`, Sync manuell.
`api-gateway` ist ein Argo Rollout, `user-service`, `trip-service`, `driver-service`, `chat-service` sind Deployments.

## Fehler-Burn

`DrovaApiGatewayBurnRateFast`, `DrovaUserServiceBurnRateFast`, `DrovaTripServiceBurnRateFast`, `DrovaDriverServiceBurnRateFast`, `DrovaChatServiceBurnRateFast`

Mehr als 7,2 % der Anfragen eines Dienstes schlagen fehl (HTTP 5xx bzw. gRPC nicht OK).

```bash
kubectl -n drova get pods -o wide | grep -v Running
kubectl -n drova logs deploy/<dienst> --since=15m | grep -iE "error|panic" | tail -30
kubectl -n drova describe rollout api-gateway | tail -30
kubectl -n argocd get application drova-prod
```

- Kurz nach einem Deploy → in `drova-gitops` zurückrollen (Revert), dann `drova-prod` manuell syncen.
- Fehler kommen von weiter hinten → [DrovaRpcHopFailing](#drovarpchopfailing), [CnpgPrimaryDown](data.md#cnpgprimarydown), [KafkaOfflinePartitions](data.md#kafkaofflinepartitions)
- drova läuft im Istio-Ambient-Mesh. Nach einem Node-Reboot fehlt Pods oft die Umleitung → [ZtunnelNodeDown](network.md#ztunnelnodedown)

## Latenz-Burn

`DrovaApiGatewayLatencyBurnRateFast`, `DrovaUserServiceLatencyBurnRateFast`, `DrovaTripServiceLatencyBurnRateFast`, `DrovaDriverServiceLatencyBurnRateFast`, `DrovaChatServiceLatencyBurnRateFast`

Mehr als 14,4 % der Anfragen brauchen länger als 500 ms. Antworten kommen, aber zu spät.

```promql
histogram_quantile(0.99, sum by (le, http_route) (rate(http_server_request_duration_seconds_bucket{service_name="api-gateway"}[5m])))
```
```bash
kubectl top pods -n drova --sort-by=cpu
kubectl cnpg status drova-postgres -n drova
```

- Im Dashboard auf den Ausschlag klicken, das Exemplar führt in den Trace. Jaegers Critical Path zeigt den langsamen Hop.
- Alle Dienste gleichzeitig langsam → gemeinsame Abhängigkeit: Postgres, Kafka, Ceph ([CephHealthError](storage.md#cephhealtherror)).

## DrovaRpcHopFailing

Harte gRPC-Fehler (`UNAVAILABLE`, `DEADLINE_EXCEEDED`, `RESOURCE_EXHAUSTED`) auf einer Strecke zwischen zwei Diensten, ununterbrochen über 10 min. Grundlast ist null.

```bash
kubectl get endpointslices -n drova | grep <ziel>
kubectl -n drova logs deploy/<ziel> --tail 50
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- hubble observe --verdict DROPPED --from-namespace drova --since 10m
```

- `UNAVAILABLE` → Ziel hat keine Endpoints, oder Traffic wird verworfen (drova hat Default-Deny für Egress).
- `DEADLINE_EXCEEDED` → Ziel zu langsam, siehe [Latenz-Burn](#latenz-burn).
