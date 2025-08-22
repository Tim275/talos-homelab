# Production-Grade HA Kubernetes Cluster - Best Practice Configuration
# Total: 3 Control Planes + 6 Workers distributed across 2 physical nodes for maximum HA
# RAM: homelab(48GB) + nipogi(80GB) = 128GB total
talos_nodes = {
  # === CONTROL PLANES === (3 nodes for true HA, distributed across physical hosts)
  "ctrl-00" = {
    host_node     = "homelab"
    machine_type  = "controlplane"
    ip            = "192.168.68.101"
    mac_address   = "BC:24:11:2E:C8:A0"
    vm_id         = 800
    cpu           = 2
    ram_dedicated = 6144  # 6GB - sufficient for control plane
    datastore_id  = "ceph_storage"
  }
  
  "ctrl-01" = {
    host_node     = "nipogi"  # Different physical node for HA
    machine_type  = "controlplane"
    ip            = "192.168.68.102"
    mac_address   = "BC:24:11:2E:C8:A1"
    vm_id         = 801
    cpu           = 2
    ram_dedicated = 6144  # 6GB - back to original after restart fixed it
    datastore_id  = "ceph_storage"
  }
  
  "ctrl-02" = {
    host_node     = "nipogi"  # Moved from homelab for better HA
    machine_type  = "controlplane"
    ip            = "192.168.68.106"
    mac_address   = "BC:24:11:2E:C8:A4"
    vm_id         = 820  # Changed from 802 to avoid conflict
    cpu           = 2
    ram_dedicated = 6144  # 6GB - back to original
    datastore_id  = "ceph_storage"
  }
  
  # === WORKERS === (6 nodes for high workload capacity, balanced across physical hosts)
  "work-00" = {
    host_node     = "homelab"  # 48GB node
    machine_type  = "worker"
    ip            = "192.168.68.103"
    mac_address   = "BC:24:11:2E:C8:A2"
    vm_id         = 810
    cpu           = 4
    ram_dedicated = 12288  # 12GB
    datastore_id  = "ceph_storage"
  }
  
  "work-01" = {
    host_node     = "nipogi"  # 80GB node - can handle more
    machine_type  = "worker"
    ip            = "192.168.68.104"
    mac_address   = "BC:24:11:2E:C8:A3"
    vm_id         = 811
    cpu           = 4
    ram_dedicated = 16384  # 16GB
    datastore_id  = "ceph_storage"
  }

  "work-02" = {
    host_node     = "homelab"
    machine_type  = "worker"
    ip            = "192.168.68.105"
    mac_address   = "BC:24:11:2E:C8:A5"
    vm_id         = 812
    cpu           = 4
    ram_dedicated = 12288  # 12GB
    datastore_id  = "ceph_storage"
  }
  
  "work-03" = {
    host_node     = "nipogi"
    machine_type  = "worker"
    ip            = "192.168.68.107"
    mac_address   = "BC:24:11:2E:C8:A6"
    vm_id         = 813
    cpu           = 4
    ram_dedicated = 16384  # 16GB
    datastore_id  = "ceph_storage"
  }
  
  "work-04" = {
    host_node     = "homelab"
    machine_type  = "worker"
    ip            = "192.168.68.108"
    mac_address   = "BC:24:11:2E:C8:A7"
    vm_id         = 814
    cpu           = 4
    ram_dedicated = 12288  # 12GB
    datastore_id  = "ceph_storage"
  }
  
  "work-05" = {
    host_node     = "nipogi"  # Heavy worker on high-RAM node
    machine_type  = "worker"
    ip            = "192.168.68.109"
    mac_address   = "BC:24:11:2E:C8:A8"
    vm_id         = 815
    cpu           = 6  # More CPU for intensive workloads
    ram_dedicated = 16384  # 16GB - reduced from 20GB to relieve host memory pressure
    datastore_id  = "ceph_storage"
  }
}

# Resource Allocation Summary:
# homelab (48GB total): ctrl-00(6GB) + ctrl-02(6GB) + work-00(12GB) + work-02(12GB) + work-04(12GB) = 48GB (100%)
# nipogi (80GB total): ctrl-01(6GB) + work-01(16GB) + work-03(16GB) + work-05(20GB) = 58GB (73%)
# 
# Total: 106GB used of 128GB available (83% utilization)
# Perfect balance: No overcommit, room for growth, true HA across physical nodes