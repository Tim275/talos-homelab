# Netzwerk

Öffentlich: Cloudflare → cloudflared (ns `cloudflared`) → Envoy Gateway (ns `gateway`) → App.
Intern: Cilium, Istio Ambient (ns `istio-system`), NetBird für den VPN-Zugang.

## HomelabEdgeDown

Mehr als die Hälfte der öffentlichen Dienste gleichzeitig weg. Unabhängige Apps fallen nicht zusammen aus, der gemeinsame Weg ist kaputt: Envoy Gateway, cloudflared oder DNS.

```bash
kubectl -n gateway logs -l control-plane=envoy-gateway --tail 200 | grep 'direct response'
kubectl -n gateway get pods
kubectl -n cloudflared get pods
```

- `direct response` im Log → [LogsGatewayRoutesDisabled](#logsgatewayroutesdisabled)
- cloudflared ohne Edge-Verbindung → [CloudflaredNoEdgeConnections](#cloudflarednoedgeconnections)

## HomelabPublicServiceDown

Die Blackbox-Probe `homelab-public-services` bekommt von einem Dienst seit 5 min keine gültige HTTP-Antwort (verweigert, Timeout oder 5xx). Als Page gilt das nur für die Kunden-App `drova.timourhomelab.org`, nach 3 min. Die Probe läuft im Cluster und löst intern auf: Sie prüft Envoy Gateway → App, nicht den Weg über Cloudflare.

```bash
curl -sk -o /dev/null -w '%{http_code}\n' --resolve drova.timourhomelab.org:443:192.168.0.152 https://drova.timourhomelab.org/
kubectl get httproute -A | grep drova
kubectl -n drova get pods -o wide | grep -v Running
kubectl -n gateway get pods
```

- Mehrere Dienste gleichzeitig → [HomelabEdgeDown](#homelabedgedown), der gemeinsame Weg ist kaputt.
- `503` → Route ohne gesunden Backend. `kubectl -n drova get endpointslices`: keine Endpoints heißt Pods nicht ready, siehe [PodCrashLooping](drova.md#podcrashlooping).
- `404` → HTTPRoute fehlt oder hängt nicht am Gateway `envoy-gateway` (`drova-frontend`, `drova-api`, `drova-login` im Namespace `drova`).
- `000` oder Timeout → Gateway-Pods oder Load-Balancer-IP, siehe [LogsGatewayRoutesDisabled](#logsgatewayroutesdisabled).
- 5xx aus der App → [Fehler-Burn](drova.md#fehler-burn).
- Probe grün, Nutzer melden trotzdem einen Ausfall → der Weg über Cloudflare ist kaputt: [CloudflaredAllDown](#cloudflaredalldown).

## LogsGatewayRoutesDisabled

Envoy Gateway konnte eine Extension- oder SecurityPolicy nicht auflösen und beantwortet betroffene Routen mit 500. Bei der WAF reicht ein einmal fehlgeschlagener WASM-Download, der Controller versucht es nicht erneut (envoyproxy/gateway#5619).

```bash
kubectl -n gateway logs -l control-plane=envoy-gateway --tail 200 | grep -B2 'setting 500 direct response'
kubectl -n gateway rollout restart deploy envoy-gateway
```

## CloudflaredAllDown

Kein cloudflared-Pod erreichbar. Alle öffentlichen Dienste sind von außen weg.

```bash
kubectl -n cloudflared get pods -o wide
kubectl -n cloudflared logs -l app=cloudflared --tail 50
kubectl -n cloudflared get secret cloudflared-credentials
```

- Pods in CrashLoop mit Auth-Fehler → Tunnel-Token prüfen, Tunnel-Status im Cloudflare-Dashboard.

## CloudflaredNoEdgeConnections

Die Pods laufen, halten aber keine Verbindung zur Cloudflare-Edge. Normal sind 4 je Pod. Blackbox-Probe und Uptime-Kuma bleiben grün, weil sie aus dem Cluster prüfen und nie über Cloudflare gehen.

```bash
kubectl -n cloudflared logs -l app=cloudflared --tail 100 | grep -iE "error|connect|register"
```
```promql
sum by (pod) (cloudflared_tunnel_ha_connections)
```

- Nur ein Pod betroffen → löschen, er kommt neu hoch.
- Alle betroffen → Tunnel-Status im Cloudflare-Dashboard, ausgehende Verbindung vom Cluster (Port 7844) prüfen, siehe [InternetConnectivityLost](#internetconnectivitylost).

## EnvoyEdgeSLOFastBurn

Die Edge verbrennt ihr Fehlerbudget 14,4× so schnell wie erlaubt, das Monatsbudget ist in rund zwei Tagen weg. Betrifft jede öffentliche App.

```promql
topk(5, sum by (envoy_cluster_name) (rate(envoy_cluster_upstream_rq_xx{envoy_response_code_class="5"}[5m])))
```
```bash
kubectl -n argocd get applications | grep -v "Synced.*Healthy"
```

- Ein Upstream dominiert → dessen Pods und letzten Deploy prüfen.
- Alle Upstreams → Gateway selbst, siehe [LogsGatewayRoutesDisabled](#logsgatewayroutesdisabled).

## InternetConnectivityLost

Mehr als die Hälfte der externen Blackbox-Ziele seit 5 min nicht erreichbar. Das Problem liegt vor dem Cluster: Router, Provider, Firewall.

```promql
probe_success{job="blackbox-external"} == 0
```
```bash
ssh root@192.168.0.50 'ping -c3 1.1.1.1; ping -c3 192.168.0.1'
```

- Router erreichbar, Internet nicht → Provider. Im Cluster ist nichts zu tun.

## CiliumAgentsCrashing

Mehr als ein Cilium-Agent nicht erreichbar. Pod-Netz auf den betroffenen Nodes gestört.

```bash
kubectl -n kube-system get pods -l k8s-app=cilium -o wide
kubectl -n kube-system logs <cilium-pod> -c cilium-agent --previous --tail 80
kubectl -n kube-system exec <cilium-pod> -c cilium-agent -- cilium-dbg status --brief
```

- Häufigste Ursache: kaputter Config-Rollout. `kubectl -n kube-system get cm cilium-config -o yaml` gegen Git vergleichen.
- Nicht zur Behebung eines Problems in einem einzelnen Namespace CNI-Einstellungen ändern (z. B. `bpf.masquerade`). Das trifft den ganzen Cluster.

## IstiodDown

istiod weg. Laufender Ambient-Traffic läuft weiter, neue Pods und Zertifikatsrotation hängen.

```bash
kubectl -n istio-system get pods -l app=istiod
kubectl get istio,ztunnel,istiocni -A
kubectl -n istio-system rollout restart deploy istiod
```

## ZtunnelNodeDown

Auf mindestens einem Node fehlt ein bereiter ztunnel. Pods im Mesh auf diesem Node verlieren ihren Traffic.

```bash
kubectl -n istio-system get pods -l app=ztunnel -o wide
kubectl -n istio-system describe ds ztunnel | tail -20
```

- Nach einem Node-Reboot verlieren laufende Pods ihre Ambient-Umleitung. Betroffene Pods neu erstellen (`kubectl delete pod`), ein Container-Neustart reicht nicht.

## NetBirdRoutingPeerDown

Ein Routing-Peer (msa2proxmox oder nipogi) ist offline. Damit ist die Route ins LAN weg und alle VPN-only-Dienste sind unerreichbar.

```bash
ssh root@192.168.0.50 'systemctl status netbird --no-pager; netbird status'
ssh root@192.168.0.57 'systemctl status netbird --no-pager; netbird status'
ssh root@<host> systemctl restart netbird
```

- Client verbunden, aber nichts erreichbar: `netbird routes ls` auf dem Client. Ausgewählt ist nicht dasselbe wie verfügbar.

## RateLimitServiceDown

envoy-ratelimit (ns `gateway`) ist weg. Der Filter fällt offen aus, es greift kein Limit mehr, auch nicht auf den öffentlichen Routen.

```bash
kubectl -n gateway get pods | grep ratelimit
kubectl -n gateway logs deploy/envoy-ratelimit --tail 50
```

- Hängt oft am Redis dahinter: `kubectl -n gateway get pod redis-gateway-0`
