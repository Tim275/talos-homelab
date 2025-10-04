talos_nodes = {
  "ctrl-0" = {
    host_node     = "nipogi"
    machine_type  = "controlplane"
    ip            = "192.168.68.101"
    mac_address   = "BC:24:11:2E:C8:A0"
    vm_id         = 1000
    cpu           = 6
    ram_dedicated = 16384
    datastore_id  = "local-zfs"
    os_disk_size  = 50  # OS + /var/lib/rook monitors (conservative increase from 20GB)
    # ceph_disk_size = 0  # Control plane has no Ceph OSD
  }
  "worker-1" = {
    host_node      = "nipogi"
    machine_type   = "worker"
    ip             = "192.168.68.103"
    mac_address    = "BC:24:11:2E:C8:A1"
    vm_id          = 1001
    cpu            = 5
    ram_dedicated  = 32768
    datastore_id   = "local-zfs"
    os_disk_size   = 50    # OS + /var/lib/rook monitors (conservative)
    ceph_disk_size = 200   # Ceph OSD (conservative 4x increase)
  }
  "worker-2" = {
    host_node      = "nipogi"
    machine_type   = "worker"
    ip             = "192.168.68.104"
    mac_address    = "BC:24:11:2E:C8:A2"
    vm_id          = 1002
    cpu            = 5
    ram_dedicated  = 32768
    datastore_id   = "local-zfs"
    os_disk_size   = 50    # OS + /var/lib/rook monitors (conservative)
    ceph_disk_size = 200   # Ceph OSD (conservative 4x increase)
  }
  "worker-3" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.68.105"
    mac_address    = "BC:24:11:2E:C8:A3"
    vm_id          = 1003
    cpu            = 8
    ram_dedicated  = 24576
    datastore_id   = "local-zfs"
    os_disk_size   = 50    # OS + /var/lib/rook monitors (conservative)
    ceph_disk_size = 200   # Ceph OSD (conservative 4x increase)
  }
  "worker-4" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.68.107"
    mac_address    = "BC:24:11:2E:C8:A4"
    vm_id          = 1004
    cpu            = 8
    ram_dedicated  = 24576
    datastore_id   = "local-zfs"
    os_disk_size   = 50    # OS + /var/lib/rook monitors (conservative)
    ceph_disk_size = 200   # Ceph OSD (conservative 4x increase)
  }
  "worker-5" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.68.108"
    mac_address    = "BC:24:11:2E:C8:A5"
    vm_id          = 1005
    cpu            = 8
    ram_dedicated  = 24576
    datastore_id   = "local-zfs"
    os_disk_size   = 50    # OS + /var/lib/rook monitors (conservative)
    ceph_disk_size = 200   # Ceph OSD (conservative 4x increase)
  }
  "worker-6" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.68.109"
    mac_address    = "BC:24:11:2E:C8:A6"
    vm_id          = 1006
    cpu            = 8
    ram_dedicated  = 24576
    datastore_id   = "local-zfs"
    os_disk_size   = 50    # OS + /var/lib/rook monitors (conservative)
    ceph_disk_size = 200   # Ceph OSD (conservative 4x increase)
  }
}
