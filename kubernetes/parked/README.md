# parked

Nicht deployt, bewusst aufgehoben. Zum Aktivieren den Ordner zurückziehen und eine Zeile im ApplicationSet ergänzen.

- audiobookshelf: ungenutzt
- backstage: nicht eingebunden
- cilium-bgp: der Router spricht kein BGP
- cilium-fqdn-egress: FQDN-Regeln, nicht aktiviert
- cloudbeaver: ersetzt durch pgadmin
- coraza-test-rig: Testaufbau für die WAF, nur von Hand
- drova-egress: Egress-Regeln für drova, nicht aktiviert
- drova-kafka-mirrormaker2: MirrorMaker-2-Demo im selben Cluster
- gatus: Statusseite läuft über uptime-kuma
- gitlab: geparkt
- grafana-datasources: grafana.com-Datenquelle, ungenutzt
- honeytoken: braucht Tetragon als Detektor
- infisical: abgelöst durch sealed-secrets und OpenBao
- istio-config: Mesh-Regeln (default-deny, STRICT, Retries), nicht aktiviert
- istio-strict-mtls: STRICT bricht unter Cilium die kubelet-Probes
- jaeger-operator: alter Operator, Scrapes laufen über monitoring
- kube-prometheus-stack-servicemonitors: kein Ziel im Cluster
- kubescape: OOMKill-Schleife
- minio: abgelöst durch die Rook-Ceph-RGW
- netbird-operator: NetBird läuft über tofu/stacks/netbird
- oms: Tenant-Vorlage
- opencost: abgeschaltet
- pod-security: Richtlinien nicht aktiviert
- proxmox-csi: abgelöst durch Rook-Ceph, das tofu-Modul bleibt
- pyroscope: geparkt
- tailscale: VPN läuft über NetBird
- tempo-trace-generator: Testlast für Tempo
- velero-aws: DR-Zeitpläne für ein AWS-Ziel
- velero-ui: ohne Login, nur per port-forward
- victoriametrics: ersetzt durch kube-prometheus-stack
