# Control Plane

ctrl-0 (192.168.0.101) ist der einzige Control-Plane-Node. Fällt er aus, laufen bestehende Pods weiter, nichts Neues passiert.
Auf welchem Proxmox-Host ctrl-0 liegt: `host_node` in `tofu/talos_nodes.auto.tfvars`, live per `ssh root@<host> qm list` bestätigen.

Ohne funktionierendes OIDC:
```bash
talosctl -n 192.168.0.101 kubeconfig
```

## ClusterAPIServerDown

apiserver seit 2 min nicht erreichbar. kubectl, ArgoCD und alle Operatoren stehen.

```bash
talosctl -n 192.168.0.101 health
talosctl -n 192.168.0.101 etcd status
talosctl -n 192.168.0.101 containers -k | grep kube-apiserver
talosctl -n 192.168.0.101 logs -k kube-system/kube-apiserver-ctrl-0:kube-apiserver:<id> --tail 50
```

- etcd steht → erst [EtcdQuorumLoss](#etcdquorumloss)
- VM aus → [ProxmoxHostDown](hosts.md#proxmoxhostdown)
- Nach einer Änderung an der Machine-Config startet der apiserver neu, rund eine Minute Ausfall ist normal

## ControlPlaneNodeDown

ctrl-0 ist NotReady. Keine Planung, kein Reconcile, kein kubectl.

```bash
kubectl get node ctrl-0 -o wide
talosctl -n 192.168.0.101 service kubelet
talosctl -n 192.168.0.101 dmesg | tail -40
ssh root@<host> 'qm list; qm status <vmid>'
```

- VM läuft, Talos antwortet: `talosctl -n 192.168.0.101 reboot`
- Nicht `qm reset` als Erstes. Erst prüfen, ob Talos noch antwortet, dann graceful rebooten.

## EtcdQuorumLoss

etcd auf ctrl-0 seit 10 min nicht erreichbar. Single-Node, es gibt kein Quorum zu verlieren, ein sauberer Neustart beschädigt nichts.

```bash
talosctl -n 192.168.0.101 service etcd
talosctl -n 192.168.0.101 etcd status
talosctl -n 192.168.0.101 logs etcd --tail 100
```

- Platte voll oder langsam → [etcdDatabaseQuotaLowSpace](#etcddatabasequotalowspace), [etcdHighFsyncDurations](#etcdhighfsyncdurations)
- Solange etcd noch liest, zuerst einen Snapshot ziehen:
  ```bash
  talosctl -n 192.168.0.101 etcd snapshot ./etcd-$(date +%F).snapshot
  ```
- Restore (`talosctl bootstrap --recover-from=<snapshot>`) nur bei nachgewiesener Korruption, nicht weil etcd gerade neu startet.

## etcdHighFsyncDurations

WAL-fsync p99 über 1 s (Page) bzw. 0,5 s (Ticket). etcd wartet auf die Platte, der apiserver wird langsam, Webhooks und Leader-Elections laufen in Timeouts.

```bash
talosctl -n 192.168.0.101 read /proc/pressure/io
talosctl -n 192.168.0.101 read /proc/diskstats
```
```promql
increase(etcd_server_slow_apply_total[24h])
histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m]))
```

- Ursache war bisher immer Konkurrenz um dieselbe physische Platte, nicht etcd selbst. Welche anderen VMs dort schreiben:
  ```bash
  ssh root@<host> 'qm list; zpool iostat -v 5 3'
  ```
- Nicht die Timeouts hochdrehen. Nicht defragmentieren, das erzeugt zusätzliche Schreiblast.

## etcdHighNumberOfFailedGRPCRequests

etcd liefert Fehler an seine Clients, fast immer der apiserver.

```bash
talosctl -n 192.168.0.101 etcd status
talosctl -n 192.168.0.101 logs etcd --tail 200 | grep -iE "error|warn|slow"
```

- `DeadlineExceeded`/`Unavailable` → langsame Platte, siehe [etcdHighFsyncDurations](#etcdhighfsyncdurations)
- `ResourceExhausted` → Quota, siehe [etcdDatabaseQuotaLowSpace](#etcddatabasequotalowspace)

## etcdDatabaseQuotaLowSpace

etcd-DB über 95 % der Quota. Bei 100 % setzt etcd den NOSPACE-Alarm und nimmt keine Writes mehr an.

```bash
talosctl -n 192.168.0.101 etcd status
talosctl -n 192.168.0.101 etcd alarm list
kubectl get --raw /metrics | grep '^apiserver_storage_objects' | sort -k2 -n | tail -10
```

- DB SIZE deutlich größer als IN USE → Fragmentierung:
  ```bash
  talosctl -n 192.168.0.101 etcd defrag
  talosctl -n 192.168.0.101 etcd alarm disarm
  ```
- IN USE wächst → wer legt so viele Objekte an? Bisherige Kandidaten: `podvolumebackups.velero.io`, `backups.velero.io`, `backups.postgresql.cnpg.io`.
- defrag blockiert etcd kurz, bei einem Single-Node hakt dann auch der apiserver.

## AdmissionWebhookRejecting

Ein Webhook mit `failurePolicy: Fail` ist nicht erreichbar. Der apiserver lehnt deshalb Creates/Updates ab, nicht weil eine Policy etwas verbietet.

```promql
sum by (name) (rate(apiserver_admission_webhook_rejection_count{error_type="calling_webhook_error"}[5m]))
```
```bash
kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations
kubectl -n <webhook-ns> get pods,endpointslices
```

- Webhook-Pod startet ständig neu → zuerst apiserver-/etcd-Latenz prüfen. Bei langsamer Platte reißen die Readiness-Deadlines der Controller.
- Nicht die WebhookConfiguration löschen, ohne zu wissen, wer sie verwaltet. Operator oder ArgoCD legen sie neu an, und bis dahin wird nichts geprüft.

## KubeSchedulerDown

Scheduler-Target seit 15 min weg. Neue Pods bleiben Pending, laufende laufen weiter.

```bash
kubectl -n kube-system get pod kube-scheduler-ctrl-0
kubectl -n kube-system logs kube-scheduler-ctrl-0 --tail 50
```
Ohne API:
```bash
talosctl -n 192.168.0.101 containers -k | grep kube-scheduler
talosctl -n 192.168.0.101 logs -k kube-system/kube-scheduler-ctrl-0:kube-scheduler:<id> --tail 50
```

- Viele `leader election lost` im Log → apiserver/etcd zu langsam, siehe [etcdHighFsyncDurations](#etcdhighfsyncdurations)

## KubeControllerManagerDown

controller-manager-Target seit 15 min weg. Deployments, Jobs und ReplicaSets konvergieren nicht mehr.

```bash
kubectl -n kube-system get pod kube-controller-manager-ctrl-0
kubectl -n kube-system logs kube-controller-manager-ctrl-0 --tail 50
```
Ohne API:
```bash
talosctl -n 192.168.0.101 containers -k | grep kube-controller-manager
talosctl -n 192.168.0.101 logs -k kube-system/kube-controller-manager-ctrl-0:kube-controller-manager:<id> --tail 50
```

- Leader-Election-Verluste → siehe [etcdHighFsyncDurations](#etcdhighfsyncdurations)

## CoreDNSDown

Keine CoreDNS-Replica ready. Cluster-DNS tot, Folgefehler überall.

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
kubectl -n kube-system logs -l k8s-app=kube-dns --tail 30
kubectl -n kube-system rollout restart deploy coredns
```

- `talosctl upgrade-k8s` überschreibt die Corefile. Danach fehlen Rewrites und Forwarder:
  ```bash
  kubectl apply -f kubernetes/infrastructure/network/coredns/base/coredns-config.yaml
  kubectl -n kube-system rollout restart deploy coredns
  ```
- Test: `kubectl run dnstest --rm -it --restart=Never --image=busybox:1.36 -- nslookup kubernetes.default`

## KubeletScrapeTargetsManyDown

Mehr als ein Drittel der kubelets liefert keine Metriken.

```bash
kubectl get nodes -o wide
talosctl -n <node-ip> service kubelet
```

- Alle Nodes Ready → Problem liegt beim Scrape (Prometheus, NetworkPolicy, TLS), nicht bei den Nodes
- Mehrere NotReady auf demselben Host → [ProxmoxHostDown](hosts.md#proxmoxhostdown)
