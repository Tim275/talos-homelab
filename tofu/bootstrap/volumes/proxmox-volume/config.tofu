locals {
  filename = "vm-${var.volume.vmid}-${var.volume.name}"
}

resource "restapi_object" "proxmox-volume" {
  path = "/api2/json/nodes/${var.volume.node}/storage/${var.volume.storage}/content"

  id_attribute = "data"

  debug = true

  data = jsonencode({
    vmid     = var.volume.vmid
    filename = local.filename
    size     = var.volume.size
    format   = var.volume.format
  })

  force_new = [var.volume.size]

  lifecycle {
    prevent_destroy = false
  }
}

output "node" {
  value = var.volume.node
}

output "storage" {
  value = var.volume.storage
}

output "filename" {
  value = local.filename
}