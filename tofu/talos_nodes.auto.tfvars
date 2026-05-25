talos_nodes = {
  "ctrl-0" = {
    host_node      = "nipogi"
    machine_type   = "controlplane"
    ip             = "192.168.0.101"
    mac_address    = "BC:24:11:2E:C8:A0"
    vm_id          = 1000
    cpu            = 6
    ram_dedicated  = 14336
    datastore_id   = "local-zfs"
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
  }
}
