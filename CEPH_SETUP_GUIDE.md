# Ceph Storage Setup Guide für Proxmox

Eine vollständige Anleitung zur Einrichtung von gemeinsamen Ceph Storage zwischen zwei Proxmox Nodes.

## Überblick

Dieses Setup erstellt einen Ceph Cluster zwischen zwei Proxmox Servern für gemeinsamen, redundanten Storage.

**Beispiel Setup:**
- **homelab** (Node 1): 192.168.68.51 - ZFS System
- **nipogi** (Node 2): 192.168.68.57 - LVM System  
- **Ziel**: ~1TB+ gemeinsamer Ceph Storage

## Voraussetzungen

- 2 Proxmox Nodes im selben Netzwerk
- SSH-Zugang zu beiden Nodes
- Verfügbarer Speicher für OSDs
- Offene Firewall-Ports: 6789, 3300, 6800-7300

## Phase 1: Ceph Cluster Initialisierung

### 1.1 Cluster auf dem ersten Node initialisieren

```bash
# Auf homelab (erster Node)
ssh root@192.168.68.51

# Ceph Cluster initialisieren (Netzwerk anpassen!)
pveceph init --network 192.168.68.0/24

# Monitor erstellen
pveceph mon create

# Manager Daemon erstellen  
pveceph mgr create

# Status prüfen
pveceph status
```

### 1.2 Zweiten Node zum Cluster hinzufügen

```bash
# Auf nipogi (zweiter Node)
ssh root@192.168.68.57

# Node zum Cluster hinzufügen
pveceph join 192.168.68.51

# Monitor auch auf zweitem Node erstellen
pveceph mon create

# Status prüfen
pveceph status
```

## Phase 2: Bootstrap-Keyrings einrichten

### 2.1 Bootstrap-Keyring auf erstem Node

```bash
# Auf homelab
ssh root@192.168.68.51

# Bootstrap-Keyring erstellen
ceph auth del client.bootstrap-osd
ceph auth get-or-create client.bootstrap-osd mon 'allow profile bootstrap-osd' -o /var/lib/ceph/bootstrap-osd/ceph.keyring

# Rechte setzen
chmod 644 /var/lib/ceph/bootstrap-osd/ceph.keyring
chown ceph:ceph /var/lib/ceph/bootstrap-osd/ceph.keyring
```

### 2.2 Bootstrap-Keyring auf zweiten Node kopieren

```bash
# Auf nipogi
ssh root@192.168.68.57

# Verzeichnis erstellen
mkdir -p /var/lib/ceph/bootstrap-osd

# Keyring von homelab kopieren
scp root@192.168.68.51:/var/lib/ceph/bootstrap-osd/ceph.keyring /var/lib/ceph/bootstrap-osd/ceph.keyring

# Rechte setzen
chmod 644 /var/lib/ceph/bootstrap-osd/ceph.keyring
chown ceph:ceph /var/lib/ceph/bootstrap-osd/ceph.keyring
```

## Phase 3: OSDs (Object Storage Daemons) erstellen

### 3.1 OSD auf ZFS System (homelab)

```bash
# Auf homelab (ZFS System)
ssh root@192.168.68.51

# ZFS Dataset für Ceph erstellen (Größe anpassen!)
zfs create -V 500G rpool/ceph-osd-homelab

# Warten bis Device verfügbar
sleep 3

# OSD mit Raw-Volume erstellen (LVM Filter umgehen)
ceph-volume raw prepare --data /dev/zvol/rpool/ceph-osd-homelab
ceph-volume raw activate --device /dev/zvol/rpool/ceph-osd-homelab

# OSD Service starten
systemctl start ceph-osd@0
systemctl enable ceph-osd@0
```

### 3.2 OSD auf LVM System (nipogi)

```bash
# Auf nipogi (LVM System)
ssh root@192.168.68.57

# Verfügbaren Speicher prüfen
vgs
lvs

# Logical Volume für Ceph erstellen (Größe anpassen!)
# Option A: Neues LV erstellen
lvcreate -L 800G -n ceph-osd pve

# Option B: Vorhandenes großes LV nutzen (falls vorhanden)
# lvcreate -l 100%FREE -n ceph-osd pve

# OSD erstellen
ceph-volume raw prepare --data /dev/pve/ceph-osd
ceph-volume raw activate --device /dev/pve/ceph-osd

# OSD Service starten  
systemctl start ceph-osd@1
systemctl enable ceph-osd@1
```

## Phase 4: Ceph Pool konfigurieren

### 4.1 Pool erstellen und konfigurieren

```bash
# Auf einem der Nodes (z.B. homelab)
ssh root@192.168.68.51

# Pool für 2-Node Setup erstellen
pveceph pool create shared_storage --size 2 --min_size 1

# Pool-Einstellungen setzen
ceph osd pool set shared_storage size 2
ceph osd pool set shared_storage min_size 1

# Status prüfen
pveceph status
```

### 4.2 Proxmox Storage hinzufügen

```bash
# Auf beiden Nodes ausführen
# Homelab:
pvesm add rbd shared_storage --pool shared_storage --monhost 192.168.68.51:6789,192.168.68.57:6789 --content images,rootdir

# Nipogi:
ssh root@192.168.68.57
pvesm add rbd shared_storage --pool shared_storage --monhost 192.168.68.51:6789,192.168.68.57:6789 --content images,rootdir
```

## Phase 5: Verifikation und Troubleshooting

### 5.1 Status überprüfen

```bash
# Ceph Cluster Status
pveceph status

# Storage Status in Proxmox
pvesm status

# OSD Status
ceph osd tree
systemctl status ceph-osd@0
systemctl status ceph-osd@1
```

### 5.2 Häufige Probleme und Lösungen

#### Problem: OSDs sind "down" oder "out"
```bash
# OSDs manuell aktivieren
ceph osd in 0
ceph osd in 1
systemctl restart ceph-osd@0
systemctl restart ceph-osd@1
```

#### Problem: "OSD count < osd_pool_default_size 3"
```bash
# Pool-Größe für 2-Node Setup anpassen
ceph osd pool set shared_storage size 2
ceph osd pool set shared_storage min_size 1
```

#### Problem: Authentication Fehler
```bash
# Bootstrap-Keyring neu erstellen
ceph auth del client.bootstrap-osd
ceph auth get-or-create client.bootstrap-osd mon 'allow profile bootstrap-osd' -o /var/lib/ceph/bootstrap-osd/ceph.keyring
```

#### Problem: LVM Filter blockiert ZFS Devices
```bash
# Raw OSDs verwenden statt LVM
ceph-volume raw prepare --data /dev/DEVICE
ceph-volume raw activate --device /dev/DEVICE
```

## Phase 6: Storage erweitern (Optional)

### 6.1 Vorhandene OSDs vergrößern

```bash
# ZFS Volume vergrößern (homelab)
zfs set volsize=1000G rpool/ceph-osd-homelab

# LV vergrößern (nipogi)
lvextend -L 1000G /dev/pve/ceph-osd
```

### 6.2 Neue OSDs hinzufügen

```bash
# Weiteren OSD auf jedem Node erstellen
# Homelab:
zfs create -V 500G rpool/ceph-osd-homelab-2
ceph-volume raw prepare --data /dev/zvol/rpool/ceph-osd-homelab-2
ceph-volume raw activate --device /dev/zvol/rpool/ceph-osd-homelab-2

# Nipogi:
lvcreate -L 500G -n ceph-osd-2 pve
ceph-volume raw prepare --data /dev/pve/ceph-osd-2  
ceph-volume raw activate --device /dev/pve/ceph-osd-2
```

## Wichtige Befehle Referenz

### Ceph Status und Monitoring
```bash
pveceph status          # Cluster Übersicht
ceph osd tree          # OSD Topologie
ceph df                # Speicher Nutzung
ceph health detail     # Detaillierte Health Info
```

### OSD Management  
```bash
systemctl start ceph-osd@N     # OSD starten
systemctl stop ceph-osd@N      # OSD stoppen  
ceph osd in N                  # OSD online bringen
ceph osd out N                 # OSD offline nehmen
```

### Pool Management
```bash
pveceph pool create POOLNAME   # Pool erstellen
ceph osd pool ls              # Pools auflisten
ceph osd pool delete POOLNAME POOLNAME --yes-i-really-really-mean-it  # Pool löschen
```

## Best Practices

1. **Netzwerk**: Verwende dedizierte Netzwerk-Interfaces für Ceph Traffic
2. **Storage**: SSDs für bessere Performance verwenden
3. **Monitoring**: Regelmäßig `pveceph status` prüfen
4. **Backups**: Ceph ersetzt keine Backups!
5. **Updates**: Ceph und Proxmox Updates vorsichtig durchführen

## Troubleshooting Checkliste

- [ ] Netzwerk-Konnektivität zwischen Nodes
- [ ] Firewall-Ports offen (6789, 3300, 6800-7300)
- [ ] Bootstrap-Keyrings vorhanden und korrekt
- [ ] OSDs haben ausreichend Speicher
- [ ] Services laufen: `systemctl status ceph-*`
- [ ] Pool-Größe korrekt für Anzahl OSDs

## Ergebnis

Nach erfolgreichem Setup:
- ✅ Gemeinsamer Ceph Storage zwischen beiden Proxmox Nodes  
- ✅ Redundante Datenspeicherung
- ✅ Live-Migration von VMs zwischen Nodes möglich
- ✅ Automatisches Failover bei Node-Ausfall

**Beispiel Endergebnis:**
```
cluster:
  health: HEALTH_OK
  
services:
  mon: 2 daemons, quorum homelab,nipogi
  mgr: homelab(active)
  osd: 2 osds: 2 up, 2 in
  
data:
  usage: 1.3 TiB used, 1.2 TiB / 1.3 TiB avail
  pools: 1 pools, 128 pgs
  objects: 0 objects, 0 B
```

---

*Guide erstellt: 2025-08-21*  
*Getestet mit: Proxmox VE 8.x, Ceph Pacific/Quincy*