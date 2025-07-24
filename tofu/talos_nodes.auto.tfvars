# Using your existing VM configuration with optimized RAM allocation
talos_nodes = {
  "ctrl-00" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.101"
    mac_address   = "BC:24:11:2E:C8:A0"
    vm_id         = 800
    cpu           = 2
    ram_dedicated = 6192  # 4GB
    datastore_id  = "local-zfs"
  }
  
  "ctrl-01" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.102"
    mac_address   = "BC:24:11:2E:C8:A1"
    vm_id         = 801
    cpu           = 2
    ram_dedicated = 6192  # 4GB
    datastore_id  = "local-zfs"
  }
  
  "ctrl-02" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.105"
    mac_address   = "BC:24:11:2E:C8:A4"
    vm_id         = 802
    cpu           = 2
    ram_dedicated = 6192  # 4GB
    datastore_id  = "local-zfs"
  }
  
  "work-00" = {
    host_node     = "homelab"
    machine_type  = "worker"
    ip            = "192.168.68.103"
    mac_address   = "BC:24:11:2E:C8:A2"
    vm_id         = 810
    cpu           = 2
    ram_dedicated = 12384  # 12GB
    datastore_id  = "local-zfs"
  }
  
  "work-01" = {
    host_node     = "homelab"
    machine_type  = "worker"
    ip            = "192.168.68.104"
    mac_address   = "BC:24:11:2E:C8:A3"
    vm_id         = 811
    cpu           = 2
    ram_dedicated = 6192  # 6GB
    datastore_id  = "local-zfs"
  }
}

# Total RAM usage: ~31GB (17GB remaining for Proxmox host + overhead)