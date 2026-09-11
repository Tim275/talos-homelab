# Node-Memory: Proxmox-Ballooning vs. Kubernetes

Kubelet liest die Node-Kapazität **einmal beim Boot**. Nimmt der Proxmox-Balloon-Treiber
der VM danach Speicher weg, erfährt Kubernetes das nie — der Scheduler packt weiter für
die Boot-Größe. Ergebnis: Kernel-OOM-Killer statt Pod-Eviction.

## Symptome

Die Kette ist unauffällig, weil kein einzelner Alert die Ursache nennt:

```
Ballooning  →  K8s glaubt 21 GiB, real 12 GiB
                    │
                    ▼   Scheduler überbucht den Node
            Kernel-OOM-Killer (kein CrashLoopBackOff!)
                    │
    ┌───────────────┼────────────────────┐
    ▼               ▼                    ▼
 Ceph-OSD      Prometheus            App-Pods
 Exit 137      Restarts              readyz 503
 → slow ping   (PVC auf Ceph)        (DB-Timeouts)
 → degraded
```

Typisch: `PrometheusPodMissing` flappt, `PodCrashLooping` feuert **nicht** (sauberer Exit,
kein BackOff), Ceph meldet `OSD_SLOW_PING_TIME` im Sekundenbereich.

## Diagnose

```bash
# 1. K8s-Sicht vs. Realität vergleichen — Kernprüfung
kubectl get nodes -o custom-columns=NODE:.metadata.name,CAPACITY:.status.capacity.memory
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
# node_memory_MemTotal_bytes  → echter RAM je instance
# weichen die Werte >2 GiB ab, ist Ballooning aktiv

# 2. OOM-Kills bestätigen
# PromQL: increase(node_vmstat_oom_kill[2h])   → >0 heißt Kernel killt

# 3. Überbuchung sehen
kubectl describe node <node> | grep -A6 "Allocated resources"
# Requests nahe/über 100% bei gleichzeitig kleinerem echten RAM = Diagnose bestätigt

# 4. Config prüfen
grep -A2 ram_dedicated tofu/talos_nodes.auto.tfvars
# ram_floating gesetzt  → Ballooning an
# ram_floating fehlt    → Node meldet ehrlich
```

## Fix

`ram_floating` entfernen. `ram_dedicated` auf den Wert setzen, den der **Host** wirklich
backen kann — nicht auf den Wunschwert.

```hcl
"worker-4" = {
  host_node     = "msa2proxmox"
  ram_dedicated = 16384          # garantiert
  # kein ram_floating
}
```

Host-Budget vorher rechnen, sonst schlägt der Start fehl:

```bash
# MemTotal und MemAvailable des Proxmox-Hosts (node_exporter auf dem Host selbst)
# Summe(ram_dedicated aller VMs) + Host-Overhead  <=  MemTotal
```

### Apply

```bash
cd tofu && tofu plan     # erwartet: floating 8192 -> 0, dedicated angepasst
tofu apply
```

⚠️ Proxmox übernimmt geänderten Speicher bei laufender VM nur mit Memory-Hotplug.
Ohne das ändert der Apply nur die VM-Config — **kubelet liest die neue Kapazität erst
nach VM-Neustart**. Worker **einzeln nacheinander** neu starten, nie parallel: sonst
verliert Ceph mehrere OSDs gleichzeitig und die PGs gehen undersized.

```bash
kubectl cordon <node> && kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
# VM in Proxmox stop/start (nicht reboot — reboot liest die neue Größe nicht)
kubectl uncordon <node>
kubectl get node <node> -o jsonpath='{.status.capacity.memory}'   # muss jetzt passen
# Ceph healthy abwarten, erst dann den nächsten Node
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph -s
```

## Warum die Alerts das nicht gezeigt haben

| Alert | Warum er schwieg |
|---|---|
| `PodCrashLooping` | prüft `CrashLoopBackOff`; OOM-Kill mit sofortigem Neustart erreicht den Zustand nie |
| `NodeMemoryPressure` | kubelet rechnet gegen die **gemeldete** Kapazität, nicht gegen die echte |
| `PrometheusPodMissing` | feuert korrekt, nennt aber das Symptom, nicht die Ursache |

Merksatz: **ein Root, viele Symptome.** Bei gleichzeitigen Restarts über mehrere
Namespaces (Storage, Monitoring, Apps) zuerst den gemeinsamen Node prüfen, nicht die
einzelnen Pods.

## Historie

| Datum | Node | K8s meldete | Real | Folge |
|---|---|---|---|---|
| 2026-09-11 | worker-4 | 21,25 GiB | 12,12 GiB | osd.1 89× OOM, Prometheus-0 180 Restarts, Ceph 20s-Heartbeats |
| 2026-09-11 | worker-3 / worker-5 | 18,2 GiB | 12,1 GiB | gleiche Config, latent |
