locals {
  cloud_init_content = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    hostname     = var.gitlab_config.name
    external_url = var.gitlab_config.external_url
    ssh_keys     = var.gitlab_config.ssh_authorized_keys
  })
}

resource "proxmox_virtual_environment_download_file" "ubuntu_image" {
  node_name    = var.gitlab_config.host_node
  content_type = "iso"
  datastore_id = "local"

  file_name = "jammy-server-cloudimg-amd64.img"
  url       = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  overwrite = true
}

# Upload cloud-init snippet directly via SSH (bypasses Proxmox API permission check)
resource "null_resource" "cloud_init_snippet" {
  triggers = {
    content_hash = sha256(local.cloud_init_content)
  }

  provisioner "file" {
    content     = local.cloud_init_content
    destination = "/var/lib/vz/snippets/gitlab-cloud-init.yaml"

    connection {
      type        = "ssh"
      host        = var.gitlab_config.host_node_ip
      user        = "root"
      private_key = file(pathexpand("~/.ssh/id_rsa_proxmox"))
    }
  }
}

resource "proxmox_virtual_environment_vm" "gitlab" {
  node_name   = var.gitlab_config.host_node
  name        = var.gitlab_config.name
  description = "GitLab CE Self-Hosted"
  tags        = ["gitlab", "ci-cd"]
  on_boot     = true
  vm_id       = var.gitlab_config.vm_id

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  bios          = "seabios"

  agent {
    enabled = true
  }

  cpu {
    cores = var.gitlab_config.cpu
    type  = "host"
  }

  memory {
    dedicated = var.gitlab_config.ram_dedicated
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = var.gitlab_config.mac_address
  }

  disk {
    datastore_id = var.gitlab_config.datastore_id
    interface    = "scsi0"
    iothread     = true
    cache        = "writethrough"
    discard      = "on"
    ssd          = true
    file_format  = "raw"
    size         = var.gitlab_config.disk_size
    file_id      = proxmox_virtual_environment_download_file.ubuntu_image.id
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id      = "local-zfs"
    user_data_file_id = "local:snippets/gitlab-cloud-init.yaml"
    dns {
      servers = ["192.168.0.1", "8.8.8.8"]
    }
    ip_config {
      ipv4 {
        address = "${var.gitlab_config.ip}/24"
        gateway = var.gitlab_config.gateway
      }
    }
  }

  lifecycle {
    create_before_destroy = false
  }

  depends_on = [
    proxmox_virtual_environment_download_file.ubuntu_image,
    null_resource.cloud_init_snippet,
  ]
}
