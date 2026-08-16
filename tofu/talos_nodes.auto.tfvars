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
    ram_dedicated       = 26624
    datastore_id        = "local-zfs"
    os_disk_size        = 50
    ceph_disk_size      = 280
    ceph_disk_datastore = "cephpool"
    # Pools spannen mehrere Zonen — sonst bricht der zone-Spread von drova-pg/kafka.
    pool = "stateful"
  }
  "worker-2" = {
    host_node           = "nipogi"
    machine_type        = "worker"
    ip                  = "192.168.0.104"
    mac_address         = "BC:24:11:2E:C8:A2"
    vm_id               = 1002
    cpu                 = 8
    ram_dedicated       = 26624
    datastore_id        = "local-zfs"
    os_disk_size        = 50
    ceph_disk_size      = 280
    ceph_disk_datastore = "cephpool"
    pool                = "stateless"
  }
  "worker-3" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.0.105"
    mac_address    = "BC:24:11:2E:C8:A3"
    vm_id          = 1003
    cpu            = 12
    ram_dedicated  = 24576
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 250
    pool           = "stateless"
  }
  "worker-4" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.0.107"
    mac_address    = "BC:24:11:2E:C8:A4"
    vm_id          = 1004
    cpu            = 12
    ram_dedicated  = 24576
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 250
    pool           = "stateful"
  }
  "worker-5" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.0.108"
    mac_address    = "BC:24:11:2E:C8:A5"
    vm_id          = 1005
    cpu            = 12
    ram_dedicated  = 24576
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 250
    pool           = "stateful"
  }

  # Future Nodes — einkommentieren sobald Hardware da

  # "ctrl-1" = {
  #   host_node      = "msa2proxmox"
  #   machine_type   = "controlplane"
  #   ip             = "192.168.0.102"
  #   mac_address    = "BC:24:11:2E:C8:B1"
  #   vm_id          = 1006
  #   cpu            = 4
  #   ram_dedicated  = 12288
  #   datastore_id   = "local-zfs"
  #   os_disk_size   = 50
  #   ceph_disk_size = 0
  # }
  # "ctrl-2" = {
  #   host_node      = "host3"
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
  "worker-6" = {
    host_node    = "pve"
    machine_type = "worker"
    ip           = "192.168.0.109"
    mac_address  = "BC:24:11:2E:C8:B3"
    vm_id        = 1008
    cpu          = 6
    # 36G statt 40G — 85%-Host-RAM-Regel (msa2/nipogi-Lektion)
    ram_dedicated = 36864
    # LVM-thin statt ZFS; 300G fuer local-path, kein Ceph-OSD
    datastore_id   = "local-lvm"
    os_disk_size   = 300
    ceph_disk_size = 0
    pool           = "stateful"
  }
}
