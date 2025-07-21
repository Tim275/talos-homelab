module "proxmox_volume" {
  for_each = var.volumes
  source   = "./proxmox-volume"

  providers = {
    restapi = restapi
  }

  proxmox_api = var.proxmox_api
  volume = {
    name    = each.key
    node    = each.value.node
    size    = each.value.size
    storage = each.value.storage
    vmid    = each.value.vmid
    format  = each.value.format
  }
}

module "persistent_volume" {
  for_each = var.volumes
  source   = "./persistent-volume"

  providers = {
    kubernetes = kubernetes
  }

  volume = {
    name          = each.key
    capacity      = each.value.size
    volume_handle = "${var.proxmox_api.cluster_name}/${module.proxmox_volume[each.key].node}/${module.proxmox_volume[each.key].storage}/${module.proxmox_volume[each.key].filename}"
    storage       = each.value.storage
  }
}