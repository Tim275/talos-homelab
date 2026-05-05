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
  proxmox_host_ips = {
    "nipogi"      = "192.168.0.57"
    "msa2proxmox" = "192.168.0.50"
  }
}

# Proxmox sets refreservation=size on every ZFS zvol it creates.
# This wastes full disk capacity twice (reserved + actual data) and causes
# apparent pool fullness. Clear on all VM disks post-creation.
# disk-0 = Ceph OSD, disk-1 = OS disk (both get cleared; 2>/dev/null ignores missing disks).
# Uses the same SSH key as the Proxmox provider (~/.ssh/id_rsa_proxmox).
resource "null_resource" "zfs_clear_refreservation" {
  for_each = var.nodes

  triggers = {
    vm_id = each.value.vm_id
  }

  provisioner "local-exec" {
    command = "ssh -i ~/.ssh/id_rsa_proxmox -o StrictHostKeyChecking=no root@${local.proxmox_host_ips[each.value.host_node]} 'zfs set refreservation=none rpool/vm-${each.value.vm_id}-disk-0 2>/dev/null; zfs set refreservation=none rpool/vm-${each.value.vm_id}-disk-1 2>/dev/null; true'"
  }

  depends_on = [proxmox_virtual_environment_vm.this]
}
