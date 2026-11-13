# kein ram_floating: Ballooning laesst kubelet den Boot-Wert melden, der Scheduler ueberpackt den Node
talos_nodes = {
  "ctrl-0" = {
    # etcd lag auf pves LENSE bei 95 C Hotspot, Laufzeiten fielen von Wochen auf Stunden
    host_node      = "msa2proxmox"
    machine_type   = "controlplane"
    ip             = "192.168.0.101"
    mac_address    = "BC:24:11:2E:C8:A0"
    vm_id          = 1010
    cpu            = 4     # 7d-Auslastung 18%
    ram_dedicated  = 10240 # 7d-Spitze 5,3 GB
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 0
  }
  # Pools spannen mehrere Zonen — sonst bricht der zone-Spread von drova-pg/kafka.
  "worker-1" = {
    host_node      = "nipogi"
    machine_type   = "worker"
    ip             = "192.168.0.103"
    mac_address    = "BC:24:11:2E:C8:A1"
    vm_id          = 1001
    cpu            = 4
    ram_dedicated  = 12288
    datastore_id   = "local-lvm"
    os_disk_size   = 50
    ceph_disk_size = 0
    pool           = "stateless"
  }
  "worker-2" = {
    host_node      = "nipogi"
    machine_type   = "worker"
    ip             = "192.168.0.104"
    mac_address    = "BC:24:11:2E:C8:A2"
    vm_id          = 1002
    cpu            = 4
    ram_dedicated  = 12288
    datastore_id   = "local-lvm"
    os_disk_size   = 50
    ceph_disk_size = 0
    pool           = "stateless"
  }
  "worker-3" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.0.105"
    mac_address    = "BC:24:11:2E:C8:A3"
    vm_id          = 1003
    cpu            = 6
    ram_dedicated  = 16384
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 0
    pool           = "stateless"
  }
  "worker-4" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.0.107"
    mac_address    = "BC:24:11:2E:C8:A4"
    vm_id          = 1004
    cpu            = 6
    ram_dedicated  = 20480
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 0
    pool           = "stateful"
  }
  "worker-5" = {
    host_node      = "msa2proxmox"
    machine_type   = "worker"
    ip             = "192.168.0.108"
    mac_address    = "BC:24:11:2E:C8:A5"
    vm_id          = 1005
    cpu            = 6
    ram_dedicated  = 20480
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 0
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
  #   host_node      = "aoostar"
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
    host_node      = "aoostar"
    machine_type   = "worker"
    ip             = "192.168.0.109"
    mac_address    = "BC:24:11:2E:C8:B3"
    vm_id          = 1008
    cpu            = 6
    ram_dedicated  = 20480
    datastore_id   = "local-zfs"
    os_disk_size   = 50
    ceph_disk_size = 0
    pool           = "stateful"
  }
}
