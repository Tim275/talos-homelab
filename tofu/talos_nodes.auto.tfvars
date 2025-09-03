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
    datastore_id  = "ceph_storage"
  }
  
  "ctrl-01" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.102"
    mac_address   = "BC:24:11:2E:C8:A1"
    vm_id         = 901
    cpu           = 4
    ram_dedicated = 6144  # 6GB
    datastore_id  = "ceph_storage"
  }
  
  "ctrl-02" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.106"
    mac_address   = "BC:24:11:2E:C8:A4"
    vm_id         = 902
    cpu           = 4
    ram_dedicated = 6144  # 6GB
    datastore_id  = "ceph_storage"
  }
  
  
  
  # === WORKERS === (Conservative allocation with safety buffers)
  "work-00" = {
    host_node     = "homelab"  # Light worker for basic workloads
    machine_type  = "worker"
    ip            = "192.168.68.103"
    mac_address   = "BC:24:11:2E:C8:A2"
    vm_id         = 910
    cpu           = 4
    ram_dedicated = 12288  # 12GB (increased from 8GB)
    datastore_id  = "ceph_storage"
  }
  
  "work-01" = {
    host_node     = "nipogi"  # Heavy worker with Ryzen power
    machine_type  = "worker"
    ip            = "192.168.68.104"
    mac_address   = "BC:24:11:2E:C8:A3"
    vm_id         = 911
    cpu           = 6
    ram_dedicated = 12288  # 12GB
    datastore_id  = "ceph_storage"
  }

  "work-02" = {
    host_node     = "homelab"  # Light worker for basic workloads
    machine_type  = "worker"
    ip            = "192.168.68.105"
    mac_address   = "BC:24:11:2E:C8:A5"
    vm_id         = 912
    cpu           = 4
    ram_dedicated = 10240  # 10GB (increased from 8GB)
    datastore_id  = "ceph_storage"
  }
  
  "work-03" = {
    host_node     = "nipogi"  # Heavy worker with Ryzen power
    machine_type  = "worker"
    ip            = "192.168.68.107"
    mac_address   = "BC:24:11:2E:C8:A6"
    vm_id         = 913
    cpu           = 6
    ram_dedicated = 12288  # 12GB
    datastore_id  = "ceph_storage"
  }
  
  "work-04" = {
    host_node     = "nipogi"  # Heavy worker with Ryzen power
    machine_type  = "worker"
    ip            = "192.168.68.108"
    mac_address   = "BC:24:11:2E:C8:A7"
    vm_id         = 914
    cpu           = 6
    ram_dedicated = 12288  # 12GB
    datastore_id  = "ceph_storage"
  }
  
  "work-05" = {
    host_node     = "nipogi"  # Heavy worker with max performance
    machine_type  = "worker"
    ip            = "192.168.68.109"
    mac_address   = "BC:24:11:2E:C8:A8"
    vm_id         = 915
    cpu           = 8  # Max CPU for intensive workloads
    ram_dedicated = 12288  # 12GB
    datastore_id  = "ceph_storage"
  }
  
  "work-06" = {
    host_node     = "nipogi"  # Heavy worker with max performance
    machine_type  = "worker"
    ip            = "192.168.68.110"
    mac_address   = "BC:24:11:2E:C8:A9"
    vm_id         = 916
    cpu           = 8  # Max CPU
    ram_dedicated = 12288  # 12GB
    datastore_id  = "ceph_storage"
  }
}



# UPDATED Resource Allocation Summary:
# homelab (48GB): ctrl-00(6GB) + ctrl-01(6GB) + ctrl-02(6GB) + work-00(12GB) + work-02(10GB) = 40GB (83% - SAFE BUFFER)
# nipogi (80GB): work-01(12GB) + work-03(12GB) + work-04(12GB) + work-05(12GB) + work-06(12GB) = 60GB (75% - SAFE BUFFER)
# 
# Total: 100GB used of 128GB available (78% utilization)
# Strategy: work-00 gets 12GB (primary homelab worker), work-02 gets 10GB  
# Benefits: +6GB homelab capacity, asymmetric allocation for workload distribution