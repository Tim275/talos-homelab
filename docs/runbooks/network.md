# Netzwerk

Öffentlich: Cloudflare → cloudflared (ns `cloudflared`) → Envoy Gateway (ns `gateway`) → App. Feste Hosts stehen in `cloudflared/overlays/prod/config.yaml`, alles andere mit öffentlichem CNAME auf den Tunnel (Kunden-Apps über `DNSEndpoint`, `login.`) läuft über die letzte Regel zum Gateway. Interne Hosts zeigen öffentlich auf die LAN-IP und erreichen den Tunnel nie.
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

Ein Routing-Peer (msa2proxmox, nipogi oder aoostar) ist offline. Die anderen routen weiter; erst wenn alle drei weg sind, sind die VPN-only-Dienste unerreichbar.

```bash
ssh root@192.168.0.50 'systemctl status netbird --no-pager; netbird status'
ssh root@192.168.0.57 'systemctl status netbird --no-pager; netbird status'
ssh root@192.168.0.59 'systemctl status netbird --no-pager; netbird status'
ssh root@<host> systemctl restart netbird
```

- Client verbunden, aber nichts erreichbar: `netbird networks ls` auf dem Client. Ausgewählt ist nicht dasselbe wie verfügbar.

## NetBird-Client auf dem Mac startet nicht

Ein Laptop ist in NetBird getrennt, `netbird status` meldet `failed to connect to daemon` und `/var/run/netbird.sock` fehlt. Zu Hause fällt es nicht auf, das LAN reicht. Unterwegs sind die VPN-only-Dienste weg. Auf dem Mac meist nach einem Neustart.

```bash
netbird status 2>&1 | tail -3
launchctl print system/netbird | grep -E "state|pid"
sfltool dumpbtm | grep -B4 -A8 "Identifier: 16.netbird" | grep Disposition
```
```promql
netbird_peer_connection_status_by_name == 0
```

- `Could not find service "netbird"` und Disposition `disallowed` → macOS erlaubt den Hintergrunddienst nicht und startet ihn nach einem Neustart nicht mehr. Systemeinstellungen → Allgemein → Anmeldeobjekte und Erweiterungen → „Im Hintergrund erlauben“ → `netbird` einschalten.
- Sofort starten: `sudo launchctl bootstrap system /Library/LaunchDaemons/netbird.plist`. Ohne die Freigabe hält das nur bis zum nächsten Neustart.
- Viele Macs: Konfigurationsprofil `com.apple.servicemanagement` mit der Regel `TeamIdentifier` `TA739QLA7A` per MDM verteilen, dann entfällt die Abfrage. Ungetestet. NetBird beschreibt die [Verteilung per MDM](https://docs.netbird.io/manage/peers/mdm-deployment/macos-cli-pkg-deployment) mit dem signierten Paket.
- Server prüfen: Der Peer steht im `netbird-exporter` als `netbird_peer_connection_status_by_name{connected="false"}`, die Routing-Peers dort als `true`.

## 403 ohne Inhalt

Eine Anfrage bekommt ein 403 ohne Text und die App sieht nichts davon. Das ist die WAF (Coraza mit den OWASP-Regeln) am Gateway. Sie lässt ohne Ausnahme nur `GET`, `HEAD`, `POST` und `OPTIONS` durch, `PUT`, `PATCH` und `DELETE` scheitern. Das trifft Oberflächen, die Daten ändern oder löschen.

Im Zugriffslog des Gateways erkennt man es an Status 403, leeren `response_code_details` und 0 gesendeten Bytes. Ein 403 der App hat Details (`via_upstream`) und einen Inhalt.

```bash
curl -si -X DELETE https://<host>/<pfad> | head -1
kubectl -n gateway logs -l app.kubernetes.io/component=proxy -c envoy --since=30m | grep '"method":"DELETE"' | grep '"response_code":403'
```

In Loki: `{namespace="gateway", container="envoy"} | json | response_code="403" | response_code_details="" | bytes_sent="0"`, gruppiert nach `_authority` und `method`.

- Echte Anfrage blockiert → Ausnahme je Host in `kubernetes/infrastructure/network/gateway/overlays/prod/coraza-waf.yaml`: `setvar:tx.allowed_methods=…`, nächste freie Regel-ID nehmen. Vorhanden für `harbor` (1100020) und `openbao` (1100025).
- Pfade wie `/.env`, `/.kube/config` oder `/phpinfo.php` → Scanner, die WAF arbeitet richtig.
- Alarme: CorazaWAFDetectionSpike und CorazaWAFBlockingSpike.

## RateLimitServiceDown

envoy-ratelimit (ns `gateway`) ist weg. Der Filter fällt offen aus, es greift kein Limit mehr, auch nicht auf den öffentlichen Routen.

```bash
kubectl -n gateway get pods | grep ratelimit
kubectl -n gateway logs deploy/envoy-ratelimit --tail 50
```

- Hängt oft am Redis dahinter: `kubectl -n gateway get pod redis-gateway-0`

## HomelabPublicServiceDown

Die Blackbox-Probe auf drova oder homepage bekommt seit 3 min keine gültige Antwort (abgelehnt, Timeout oder 5xx).

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://drova.timourhomelab.org
curl -s -o /dev/null -w '%{http_code}\n' --resolve drova.timourhomelab.org:443:192.168.0.152 https://drova.timourhomelab.org
kubectl -n cloudflared get pods
```

- Öffentlich 530, über `--resolve` 200 → Tunnel: [CloudflaredAllDown](#cloudflaredalldown)
- Beides scheitert → Gateway oder App: [HomelabEdgeDown](#homelabedgedown)
- Nur drova betroffen → [Fehler-Burn](drova.md#fehler-burn)
