# Optimized Kubernetes Cluster - Hardware-Based Distribution
# homelab: 48GB RAM (UPGRADED!), nipogi: 80GB RAM (Total: 128GB)
talos_nodes = {
  # === CONTROL PLANES === (All on homelab for stability)
  "ctrl-00" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.101"
    mac_address   = "BC:24:11:2E:C8:A0"
    vm_id         = 900
    cpu           = 3  # Optimized: 3 CPU cores for stability
    ram_dedicated = 8192  # 8GB - generous for K8s + ArgoCD
    datastore_id  = "local-zfs"
  }
  
  "ctrl-01" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.102"
    mac_address   = "BC:24:11:2E:C8:A1"
    vm_id         = 901
    cpu           = 3  # Optimized: 3 CPU cores for stability
    ram_dedicated = 8192  # 8GB - generous for K8s + ArgoCD
    datastore_id  = "local-zfs"
  }
  
  "ctrl-02" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.106"
    mac_address   = "BC:24:11:2E:C8:A4"
    vm_id         = 902
    cpu           = 3  # Optimized: 3 CPU cores for stability
    ram_dedicated = 8192  # 8GB - generous for K8s + ArgoCD
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
    ram_dedicated = 8704  # 8.5GB (85% nipogi utilization)
    datastore_id  = "local-zfs"
  }
  
  "work-02" = {
    host_node     = "nipogi"  # Heavy worker with Ryzen power
    machine_type  = "worker"
    ip            = "192.168.68.105"
    mac_address   = "BC:24:11:2E:C8:A2"
    vm_id         = 912
    cpu           = 6
    ram_dedicated = 8704  # 8.5GB (85% nipogi utilization)
    datastore_id  = "local-zfs"
  }
  
  "work-03" = {
    host_node     = "nipogi"  # Heavy worker with Ryzen power
    machine_type  = "worker"
    ip            = "192.168.68.107"
    mac_address   = "BC:24:11:2E:C8:A6"
    vm_id         = 913
    cpu           = 6
    ram_dedicated = 8704  # 8.5GB (85% nipogi utilization)
    datastore_id  = "local-zfs"
  }
  
  "work-04" = {
    host_node     = "nipogi"  # Heavy worker with Ryzen power
    machine_type  = "worker"
    ip            = "192.168.68.108"
    mac_address   = "BC:24:11:2E:C8:A7"
    vm_id         = 914
    cpu           = 6
    ram_dedicated = 8704  # 8.5GB (85% nipogi utilization)
    datastore_id  = "local-zfs"
  }
  
  "work-05" = {
    host_node     = "nipogi"  # Heavy worker with max performance
    machine_type  = "worker"
    ip            = "192.168.68.109"
    mac_address   = "BC:24:11:2E:C8:A8"
    vm_id         = 915
    cpu           = 8  # Max CPU for intensive workloads
    ram_dedicated = 8704  # 8.5GB (85% nipogi utilization)
    datastore_id  = "local-zfs"
  }
  
  "work-06" = {
    host_node     = "nipogi"  # Heavy worker with max performance
    machine_type  = "worker"
    ip            = "192.168.68.110"
    mac_address   = "BC:24:11:2E:C8:A9"
    vm_id         = 916
    cpu           = 8  # Max CPU
    ram_dedicated = 8704  # 8.5GB (85% nipogi utilization)
    datastore_id  = "local-zfs"
  }
  
  "work-07" = {
    host_node     = "nipogi"  # EXTREME POWER WORKER
    machine_type  = "worker"
    ip            = "192.168.68.111"
    mac_address   = "BC:24:11:2E:C8:AA"
    vm_id         = 917
    cpu           = 8  # Max CPU for extreme workloads
    ram_dedicated = 8704  # 8.5GB (85% nipogi utilization)
    datastore_id  = "local-zfs"
  }
  
  "work-08" = {
    host_node     = "nipogi"  # ULTIMATE POWER WORKER
    machine_type  = "worker"
    ip            = "192.168.68.112"
    mac_address   = "BC:24:11:2E:C8:AB"
    vm_id         = 918
    cpu           = 8  # Max CPU for ultimate performance
    ram_dedicated = 8704  # 8.5GB (85% nipogi utilization)
    datastore_id  = "local-zfs"
  }
  
}



# 💪 OPTIMIZED Resource Allocation Summary:
# homelab (48GB): ctrl-00(8GB) + ctrl-01(8GB) + ctrl-02(8GB) = 24GB (50% - PERFECT BALANCE)
# nipogi (80GB = 16GB + 64GB SSD): work-01 to work-08 (8x 8.5GB) = 68GB (85% - OPTIMAL POWER!)
# 
# Total: 92GB used of 128GB available (72% utilization)
# Strategy: homelab stability + nipogi at 85% optimal capacity with 8 workers!
# Benefits: Maximum performance while maintaining system stability