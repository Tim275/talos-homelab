talos_nodes = {
  "ctrl-0" = {
    host_node      = "nipogi"
    machine_type   = "controlplane"
    ip             = "192.168.68.101"
    mac_address    = "BC:24:11:2E:C8:A0"
    vm_id          = 1000
    cpu            = 8
    ram_dedicated  = 16384
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 0
  }
  "worker-1" = {
    host_node      = "nipogi"
    machine_type   = "worker"
    ip             = "192.168.68.103"
    mac_address    = "BC:24:11:2E:C8:A1"
    vm_id          = 1001
    cpu            = 5
    ram_dedicated  = 28672
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 170
  }
  "worker-2" = {
    host_node      = "nipogi"
    machine_type   = "worker"
    ip             = "192.168.68.104"
    mac_address    = "BC:24:11:2E:C8:A2"
    vm_id          = 1002
    cpu            = 5
    ram_dedicated  = 28672
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 170
  }
  "worker-3" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.68.105"
    mac_address    = "BC:24:11:2E:C8:A3"
    vm_id          = 1003
    cpu            = 8
    ram_dedicated  = 20480
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 170
  }
  "worker-4" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.68.107"
    mac_address    = "BC:24:11:2E:C8:A4"
    vm_id          = 1004
    cpu            = 8
    ram_dedicated  = 20480
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 170
  }
  "worker-5" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.68.108"
    mac_address    = "BC:24:11:2E:C8:A5"
    vm_id          = 1005
    cpu            = 8
    ram_dedicated  = 20480
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 170
  }
  "worker-6" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.68.109"
    mac_address    = "BC:24:11:2E:C8:A6"
    vm_id          = 1006
    cpu            = 8
    ram_dedicated  = 20480
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 170
  }
  "worker-7" = {
    host_node      = "nipogi"
    machine_type   = "worker"
    ip             = "192.168.68.110"
    mac_address    = "BC:24:11:2E:C8:A9"
    vm_id          = 1007
    cpu            = 4
    ram_dedicated  = 12288
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 170
  }
}
