# Optimized Kubernetes Cluster - Hardware-Based Distribution
# homelab: 48GB RAM, nipogi: 80GB RAM (Total: 128GB)
talos_nodes = {
  # === CONTROL PLANES === (All on homelab for stability)
  "ctrl-00" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.101"
    mac_address   = "BC:24:11:2E:C8:A0"
    vm_id         = 900
    cpu           = 4
    ram_dedicated = 6144  # 6GB
    datastore_id  = "local-zfs"
  }
  
  "ctrl-01" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.102"
    mac_address   = "BC:24:11:2E:C8:A1"
    vm_id         = 901
    cpu           = 4
    ram_dedicated = 6144  # 6GB
    datastore_id  = "local-zfs"
  }
  
  "ctrl-02" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.106"
    mac_address   = "BC:24:11:2E:C8:A4"
    vm_id         = 902
    cpu           = 4
    ram_dedicated = 6144  # 6GB
    datastore_id  = "local-zfs"
  }
  
  
  
  # === WORKERS === (Only on nipogi - homelab only runs control planes)
  "work-01" = {
    host_node     = "nipogi"  # Heavy worker with Ryzen power
    machine_type  = "worker"
    ip            = "192.168.68.104"
    mac_address   = "BC:24:11:2E:C8:A3"
    vm_id         = 911
    cpu           = 6
    ram_dedicated = 14336  # 14GB (+2GB for Ceph)
    datastore_id  = "local-zfs"
  }
  
  "work-03" = {
    host_node     = "nipogi"  # Heavy worker with Ryzen power
    machine_type  = "worker"
    ip            = "192.168.68.107"
    mac_address   = "BC:24:11:2E:C8:A6"
    vm_id         = 913
    cpu           = 6
    ram_dedicated = 14336  # 14GB (+2GB for Ceph)
    datastore_id  = "local-zfs"
  }
  
  "work-04" = {
    host_node     = "nipogi"  # Heavy worker with Ryzen power
    machine_type  = "worker"
    ip            = "192.168.68.108"
    mac_address   = "BC:24:11:2E:C8:A7"
    vm_id         = 914
    cpu           = 6
    ram_dedicated = 14336  # 14GB (+2GB for Ceph)
    datastore_id  = "local-zfs"
  }
  
  "work-05" = {
    host_node     = "nipogi"  # Heavy worker with max performance
    machine_type  = "worker"
    ip            = "192.168.68.109"
    mac_address   = "BC:24:11:2E:C8:A8"
    vm_id         = 915
    cpu           = 8  # Max CPU for intensive workloads
    ram_dedicated = 14336  # 14GB (+2GB for Ceph)
    datastore_id  = "local-zfs"
  }
  
  "work-06" = {
    host_node     = "nipogi"  # Heavy worker with max performance
    machine_type  = "worker"
    ip            = "192.168.68.110"
    mac_address   = "BC:24:11:2E:C8:A9"
    vm_id         = 916
    cpu           = 8  # Max CPU
    ram_dedicated = 14336  # 14GB (+2GB for Ceph)
    datastore_id  = "local-zfs"
  }
}



# UPDATED Resource Allocation Summary:
# homelab (48GB): ctrl-00(6GB) + ctrl-01(6GB) + ctrl-02(6GB) = 18GB (38% - LOTS OF HEADROOM)
# nipogi (80GB): work-01(14GB) + work-03(14GB) + work-04(14GB) + work-05(14GB) + work-06(14GB) = 70GB (88% - SAFE)
# 
# Total: 88GB used of 128GB available (69% utilization)
# Strategy: NO WORKERS on homelab to prevent crashes, all workers on nipogi
# Benefits: homelab stability, dedicated control plane/worker separation