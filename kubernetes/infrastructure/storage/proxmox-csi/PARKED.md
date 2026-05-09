# Proxmox CSI — PARKED

**Status:** Folder existiert, NICHT in `storage/kustomization.yaml`. Replaced durch Rook-Ceph RBD.

## Warum entfernt

- Proxmox CSI = Block-Storage direkt von Proxmox-VM-Disks
- Funktioniert, aber: keine 3-fach Replikation, single-host failure-domain
- Rook-Ceph RBD bietet replicated, anti-affine PVCs

## Wann hätte Proxmox CSI Sinn?

- Wenn ZFS-Snapshots auf Proxmox-Seite genutzt werden sollen
- Wenn nur 1 Worker-Node und Disk-Sharing zwischen K8s + Proxmox-VMs gewollt

## Restore

```bash
# storage/kustomization.yaml: + - proxmox-csi/application.yaml
```
