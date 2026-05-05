resource "proxmox_virtual_environment_vm" "this" {
  for_each = var.nodes

  node_name = each.value.host_node

  name        = each.key
  description = each.value.machine_type == "controlplane" ? "Talos Control Plane" : "Talos Worker"
  tags        = each.value.machine_type == "controlplane" ? ["k8s", "control-plane"] : ["k8s", "worker"]
  on_boot     = true
  vm_id       = each.value.vm_id

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  bios          = "seabios"

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated = each.value.ram_dedicated
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = each.value.mac_address
  }

  # Talos OS Disk - Per-node sizing
  disk {
    datastore_id = each.value.datastore_id
    interface    = "scsi0"
    iothread     = true
    cache        = "writethrough"
    discard      = "on"
    ssd          = true
    file_format  = "raw"
    # OLD: size = 20  # Original size
    # OLD: size = 30  # First increase (commented commit)
    size    = each.value.os_disk_size  # Conservative: 50GB for all nodes
    file_id = proxmox_virtual_environment_download_file.this["${each.value.host_node}_${each.value.update == true ? local.update_image_id : local.image_id}"].id
  }

  # Ceph Storage Disk (raw, unformatted) - Per-node sizing
  # IMPORTANT: Only create if ceph_disk_size > 0 (control planes don't need Ceph disk)
  dynamic "disk" {
    for_each = each.value.ceph_disk_size > 0 ? [1] : []
    content {
      datastore_id = each.value.datastore_id
      interface    = "scsi1"
      iothread     = true
      cache        = "none"
      discard      = "on"
      ssd          = true
      file_format  = "raw"
      size         = each.value.ceph_disk_size
    }
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = each.value.datastore_id
    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.cluster.subnet_mask}"
        gateway = var.cluster.gateway
      }
    }
  }

  dynamic "hostpci" {
    for_each = each.value.igpu ? [1] : []
    content {
      device  = "hostpci0"
      mapping = "iGPU"
      pcie    = true
      rombar  = true
      xvga    = false
    }
  }

  lifecycle {
    create_before_destroy = false
  }

  # Force serial creation to prevent SSH overload
  depends_on = [
    proxmox_virtual_environment_download_file.this
  ]
}

locals {
  nipogi_ceph_nodes = {
    for k, v in var.nodes : k => v
    if v.host_node == "nipogi" && v.ceph_disk_size > 0
  }
}

# Proxmox automatically sets refreservation=size on every ZFS zvol it creates.
# For Ceph OSD disks this wastes the full disk capacity twice (reserved + actual data).
# This clears it post-creation so the ZFS pool reports realistic usage.
resource "null_resource" "zfs_clear_nipogi_refreservation" {
  for_each = var.nipogi_ssh_password != "" ? local.nipogi_ceph_nodes : {}

  triggers = {
    vm_id          = each.value.vm_id
    ceph_disk_size = each.value.ceph_disk_size
  }

  provisioner "local-exec" {
    command     = "sshpass -p \"$NIPOGI_PASS\" ssh -o StrictHostKeyChecking=no root@192.168.0.57 'zfs set refreservation=none rpool/data/vm-${each.value.vm_id}-disk-1 2>/dev/null || true'"
    environment = {
      NIPOGI_PASS = var.nipogi_ssh_password
    }
  }

  depends_on = [proxmox_virtual_environment_vm.this]
}
