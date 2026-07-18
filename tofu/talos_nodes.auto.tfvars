talos_nodes = {
  "ctrl-0" = {
    host_node     = "nipogi"
    machine_type  = "controlplane"
    ip            = "192.168.0.101"
    mac_address   = "BC:24:11:2E:C8:A0"
    vm_id         = 1000
    cpu           = 6
    ram_dedicated = 14336
    # etcd-fsync: ctrl-0 OS-Disk auf Samsung (cephpool), nicht HOGE (local-zfs)
    datastore_id   = "cephpool"
    os_disk_size   = 50
    ceph_disk_size = 0
  }
  "worker-1" = {
    host_node           = "nipogi"
    machine_type        = "worker"
    ip                  = "192.168.0.103"
    mac_address         = "BC:24:11:2E:C8:A1"
    vm_id               = 1001
    cpu                 = 8
    ram_dedicated       = 28672
    datastore_id        = "local-zfs"
    os_disk_size        = 50
    ceph_disk_size      = 170
    ceph_disk_datastore = "cephpool"
    # node-pool prep (inaktiv bis neue Hardware): stateful=w1/w4/w5, stateless=w2/w3.
    # Beide Pools spannen BEIDE Zonen — zone-Spread von drova-pg/kafka bricht sonst.
    # Aktivierung OHNE tofu apply (Drift!): talosctl patch machineconfig nodeLabels + hier einkommentieren.
    # pool              = "stateful"
  }
  "worker-2" = {
    host_node           = "nipogi"
    machine_type        = "worker"
    ip                  = "192.168.0.104"
    mac_address         = "BC:24:11:2E:C8:A2"
    vm_id               = 1002
    cpu                 = 8
    ram_dedicated       = 28672
    datastore_id        = "local-zfs"
    os_disk_size        = 50
    ceph_disk_size      = 170
    ceph_disk_datastore = "cephpool"
    # pool              = "stateless"
  }
  "worker-3" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.0.105"
    mac_address    = "BC:24:11:2E:C8:A3"
    vm_id          = 1003
    cpu            = 12
    ram_dedicated  = 26624
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 250
    # pool         = "stateless"
  }
  "worker-4" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.0.107"
    mac_address    = "BC:24:11:2E:C8:A4"
    vm_id          = 1004
    cpu            = 12
    ram_dedicated  = 26624
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 250
    # pool         = "stateful"
  }
  "worker-5" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.0.108"
    mac_address    = "BC:24:11:2E:C8:A5"
    vm_id          = 1005
    cpu            = 12
    ram_dedicated  = 26624
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 250
    # pool         = "stateful"
  }

  # ─── FUTURE NODES (vorbereitet, einkommentieren sobald neue Hardware da) ───
  # IP/MAC/vm_id sind Platzhalter (frei: .102/.106/.109+, vm 1006+) — vor Aktivierung setzen.
  # Reihenfolge: erst host3 in Proxmox, dann ctrl-1+ctrl-2 (etcd 1→3 = SPOF weg),
  # dann worker-6 als ai-Pool (Taint hält Alltagslast fern, MLOps-Roadmap).

  # "ctrl-1" = {
  #   host_node      = "msa2proxmox"   # CP-Spread: nipogi + msa2 + host3
  #   machine_type   = "controlplane"
  #   ip             = "192.168.0.102"
  #   mac_address    = "BC:24:11:2E:C8:B1"
  #   vm_id          = 1006
  #   cpu            = 4
  #   ram_dedicated  = 12288
  #   datastore_id   = "local-zfs"     # etcd-fsync: beste Disk des Hosts nehmen!
  #   os_disk_size   = 50
  #   ceph_disk_size = 0
  # }
  # "ctrl-2" = {
  #   host_node      = "host3"         # erst mit 3. Host ueberlebt etcd einen HOST-Ausfall
  #   machine_type   = "controlplane"
  #   ip             = "192.168.0.106"
  #   mac_address    = "BC:24:11:2E:C8:B2"
  #   vm_id          = 1007
  #   cpu            = 4
  #   ram_dedicated  = 12288
  #   datastore_id   = "local-zfs"
  #   os_disk_size   = 50
  #   ceph_disk_size = 0
  # }
  # "worker-6" = {
  #   host_node      = "host3"
  #   machine_type   = "worker"
  #   ip             = "192.168.0.109"
  #   mac_address    = "BC:24:11:2E:C8:B3"
  #   vm_id          = 1008
  #   cpu            = 12
  #   ram_dedicated  = 32768
  #   datastore_id   = "local-zfs"
  #   os_disk_size   = 50
  #   ceph_disk_size = 250             # host3-OSDs => Ceph 3. Zone => size-3-Pools moeglich
  #   # pool         = "ai"            # + Taint dedicated=ai:NoSchedule (GPU/ML exklusiv)
  # }
}
