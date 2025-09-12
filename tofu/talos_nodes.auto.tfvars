talos_nodes = {
  "ctrl-00" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.101"
    mac_address   = "BC:24:11:2E:C8:A0"
    vm_id         = 900
    cpu           = 4
    ram_dedicated = 10240
    datastore_id  = "local-zfs"
  }
  
  "ctrl-01" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.102"
    mac_address   = "BC:24:11:2E:C8:A1"
    vm_id         = 901
    cpu           = 4
    ram_dedicated = 10240
    datastore_id  = "local-zfs"
  }
  
  "ctrl-02" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.106"
    mac_address   = "BC:24:11:2E:C8:A4"
    vm_id         = 902
    cpu           = 4
    ram_dedicated = 10240
    datastore_id  = "local-zfs"
  }
  
  "work-01" = {
    host_node     = "nipogi"
    machine_type  = "worker"
    ip            = "192.168.68.104"
    mac_address   = "BC:24:11:2E:C8:A3"
    vm_id         = 911
    cpu           = 8
    ram_dedicated = 32768
    datastore_id  = "local-zfs"
    # NEU: Node Labels (für später)
    # labels = {
    #   "node-type" = "stateful"
    #   "storage"   = "ssd"
    #   "host"      = "nipogi"
    # }
    # NEU: Taints (optional - erstmal NICHT!)
    # taints = [
    #   {
    #     key    = "workload"
    #     value  = "database"
    #     effect = "NoSchedule"
    #   }
    # ]
  }
  
  "work-02" = {
    host_node     = "nipogi"
    machine_type  = "worker"
    ip            = "192.168.68.105"
    mac_address   = "BC:24:11:2E:C8:A2"
    vm_id         = 912
    cpu           = 8
    ram_dedicated = 32768
    datastore_id  = "local-zfs"
    # NEU: Node Labels (für später)
    # labels = {
    #   "node-type" = "stateful"
    #   "storage"   = "ssd"
    #   "host"      = "nipogi"
    # }
  }
  
  "work-03" = {
    host_node     = "msa2proxmox"
    machine_type  = "worker"
    ip            = "192.168.68.107"
    mac_address   = "BC:24:11:2E:C8:A6"
    vm_id         = 913
    cpu           = 12
    ram_dedicated = 20480
    datastore_id  = "local-zfs"
    # NEU: Node Labels (für später)
    # labels = {
    #   "node-type" = "compute"
    #   "cpu"       = "high"
    #   "host"      = "msa2proxmox"
    # }
  }
  
  "work-04" = {
    host_node     = "msa2proxmox"
    machine_type  = "worker"
    ip            = "192.168.68.108"
    mac_address   = "BC:24:11:2E:C8:A7"
    vm_id         = 914
    cpu           = 12
    ram_dedicated = 20480
    datastore_id  = "local-zfs"
    # NEU: Node Labels (für später)
    # labels = {
    #   "node-type" = "compute"
    #   "cpu"       = "high"
    #   "host"      = "msa2proxmox"
    # }
  }
  
  "work-05" = {
    host_node     = "msa2proxmox"
    machine_type  = "worker"
    ip            = "192.168.68.109"
    mac_address   = "BC:24:11:2E:C8:A8"
    vm_id         = 915
    cpu           = 12
    ram_dedicated = 20480
    datastore_id  = "local-zfs"
    # NEU: Node Labels (für später)
    # labels = {
    #   "node-type" = "compute"
    #   "cpu"       = "high"
    #   "host"      = "msa2proxmox"
    # }
  }
  
  "work-06" = {
    host_node     = "msa2proxmox"
    machine_type  = "worker"
    ip            = "192.168.68.110"
    mac_address   = "BC:24:11:2E:C8:A9"
    vm_id         = 916
    cpu           = 8
    ram_dedicated = 20480
    datastore_id  = "local-zfs"
    # NEU: Node Labels (für später)
    # labels = {
    #   "node-type" = "compute"
    #   "cpu"       = "high"
    #   "host"      = "msa2proxmox"
    # }
  }
}

# Note: Rook-CEPH will be deployed via Kubernetes Operator (not VM-level CEPH)
# VM-level CEPH would require additional 16GB+ RAM per node - exceeds homelab i5 capacity
