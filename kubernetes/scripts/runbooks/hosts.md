# Proxmox-Hosts

| Host | IP |
|---|---|
| msa2proxmox | 192.168.0.50 |
| nipogi | 192.168.0.57 |
| pve | 192.168.0.58 |

Welche VM auf welchem Host liegt, ändert sich. Nie aus dem Gedächtnis, immer live: `ssh root@<ip> qm list`.
Soll-Zuordnung: `host_node` in `tofu/talos_nodes.auto.tfvars`.

## ProxmoxHostDown

node-exporter eines Hosts seit 5 min weg. Meist ist der ganze Host samt VMs weg.

```bash
ping -c3 <ip>
ssh root@<ip> 'uptime; qm list; systemctl is-active node_exporter'
kubectl get nodes -o wide
```

- Nur der Exporter ist tot: `ssh root@<ip> systemctl restart node_exporter`
- Host erreichbar, aber langsam oder Nodes flappen → Netzwerklink prüfen. Ein halb steckendes Kabel läuft mit 100 statt 1000 Mbit:
  ```bash
  ssh root@<ip> 'ethtool <nic> | grep -E "Speed|Link detected"'
  ```
- msa2 hängt nach Stromausfall im GRUB: Strom komplett trennen, CMOS-Batterie kurz raus. Kein Plattentausch.
- Proxmox-Cluster ohne Quorum (VMs starten nicht, `pvecm status` zeigt `Quorate: No`), wenn nur ein Host läuft:
  ```bash
  ssh root@<ip> 'pvecm status; pvecm expected 1'
  ```
- Nicht `qm reset` als Erstes. Erst `qm status <vmid>`, dann `talosctl -n <node-ip> reboot`.

## KubeMultipleNodesNotReady

Zwei oder mehr Nodes seit 5 min NotReady, gecordonte zählen nicht. Die Redundanz ist aufgebraucht, ein weiterer Ausfall nimmt Workloads mit. Fällt ein ganzer Proxmox-Host aus, meldet sich zusätzlich [ProxmoxHostDown](#proxmoxhostdown) und unterdrückt diesen Alarm.

```bash
kubectl get nodes -L topology.kubernetes.io/zone -o wide
kubectl describe node <node> | grep -A8 Conditions
kubectl get pods -A -o wide --field-selector spec.nodeName=<node> | grep -v Running
talosctl -n <node-ip> health
```

- Das Zonen-Label ist der Proxmox-Host. Alle betroffenen Nodes in derselben Zone → Host oder Netzwerk dieses Hosts: [ProxmoxHostDown](#proxmoxhostdown).
- Nodes aus mehreren Zonen → Cluster-Netz oder Control Plane: [ControlPlaneNodeDown](control-plane.md#controlplanenodedown), [CiliumAgentsCrashing](network.md#ciliumagentscrashing).
- Node erreichbar, kubelet aber NotReady:
  ```bash
  talosctl -n <node-ip> service kubelet
  talosctl -n <node-ip> dmesg | tail -50
  ```
- Nicht alle Nodes sofort neu starten. Erst klären, ob Host oder Netz die Ursache sind, sonst starten die VMs gegen dieselbe Störung neu. Reihenfolge wie bei ProxmoxHostDown.

## ProxmoxHostRebootLoop

Host ist in 7 Tagen mehr als zweimal neu gestartet. Ein Reboot ist Rauschen, ein Muster ist ein Defekt.

```bash
ssh root@<ip> 'last -x reboot | head; sysctl kernel.panic; systemctl is-active watchdog-mux'
ssh root@<ip> 'journalctl -b -1 -p err --no-pager | tail -30'
```

- `kernel.panic = 0` → der Reset kam vom Watchdog, nicht vom Kernel. Dann im pvestatd-Log nach blockierenden Storages suchen: `journalctl -u pvestatd -b -1 | tail -50`
- Mit den anderen beiden Hosts vergleichen.

## ProxmoxStorageCritical

Storage über 85 %. ZFS wird darüber langsam, LVM-thin bei 100 % schaltet Volumes read-only und beschädigt VMs.

```bash
ssh root@<ip> 'pvesm status'
ssh root@<ip> 'zfs list -o name,used,avail,refer -s used | tail -15'
ssh root@<ip> 'zfs list -t snapshot -o name,used -s used | tail -10'
ssh root@<ip> 'zfs get -r -H -o name,value refreservation <pool> | grep -v none'
ssh root@<ip> 'lvs'
```

- Alte Snapshots löschen, erst dann an VM-Disks denken.
- Volumes mit `refreservation` belegen ihre volle Größe, auch wenn sie leer sind. Für `local-zfs` ist `sparse 1` in `/etc/pve/storage.cfg` gesetzt.
- Nicht eine VM-Disk löschen, ohne vorher `qm config <vmid>` geprüft zu haben.

## ProxmoxZfsPoolCritical

ZFS-Pool in faulted/unavail/suspended/removed. Daten auf dem Pool sind gefährdet.

```bash
ssh root@<ip> 'zpool status -x'
ssh root@<ip> 'zpool status -v <pool>'
ssh root@<ip> 'smartctl -a /dev/<disk>'
```

- Defekte Platte ersetzen: `zpool replace <pool> <alt> <neu>`, danach Resilver in `zpool status` beobachten.
- Bei Single-Disk-Pools gibt es nichts zu resilvern. Dann zählen nur Ceph-Replikas auf den anderen Hosts und Backups.

## HostRootFilesystemCritical

Root-Dateisystem unter 5 % frei. Schreibfehler, hängende Dienste.

```bash
ssh root@<ip> 'df -h /; du -xsh /var/* 2>/dev/null | sort -h | tail'
ssh root@<ip> 'journalctl --vacuum-size=200M'
```

## HostCPUTemperatureCritical

CPU seit 15 min über 95 °C. Thermischer Shutdown droht.

```bash
ssh root@<ip> sensors
```
```promql
node_hwmon_temp_celsius{chip=~"platform_coretemp.*"}
```

- Physisch: Staub, Lüfter, Luftstrom. Bis dahin Last runternehmen.

## HostBridgeDown

Eine `vmbr`-Bridge ist down. Aller VM- und Host-Traffic darüber ist weg, auch Ceph.

```bash
ssh root@<ip> 'ip -br link; bridge link'
ssh root@<ip> 'ethtool <nic> | grep -E "Speed|Link detected"'
ssh root@<ip> 'ifreload -a'
```

- Kein Link auf der physischen NIC → Kabel/Switchport. Konfig in `/etc/network/interfaces`.

## SSDSmartHealthFailed

SMART-Selbsttest einer Platte sagt FAILED. Ausfall absehbar.

```bash
ssh root@<ip> 'smartctl -a /dev/<device>'
ssh root@<ip> 'qm list; pvesm status'
kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd tree
```

- Welche VMs auf der Platte liegen, bestimmt, welche OSDs mitsterben. Mehrere OSD-Nodes können auf derselben NVMe liegen.
- Vor Wartung: `ceph osd set noout`, danach `ceph osd unset noout`.
- Nicht OSDs auf mehreren Nodes gleichzeitig rausnehmen.

## SSDCriticalWarning

NVMe-Critical-Warning-Bits gesetzt (Spare, Zuverlässigkeit, read-only). Temperatur ist ausgenommen.

```bash
ssh root@<ip> 'smartctl -a /dev/<device> | grep -iA8 "critical warning"'
```

Weiter wie bei [SSDSmartHealthFailed](#ssdsmarthealthfailed).

## SSDMediaErrors

Neue, nicht korrigierbare NAND-Fehler in der letzten Stunde. Die Platte stirbt.

```bash
ssh root@<ip> 'smartctl -a /dev/<device> | grep -iE "media|error"'
```

Weiter wie bei [SSDSmartHealthFailed](#ssdsmarthealthfailed).
