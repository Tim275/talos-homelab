import {
  to = proxmox_storage_zfspool.local_zfs
  id = "local-zfs"
}

resource "proxmox_storage_zfspool" "local_zfs" {
  id             = "local-zfs"
  zfs_pool       = "rpool/data"
  nodes          = ["msa2proxmox", "aoostar"]
  content        = ["images", "rootdir"]
  thin_provision = true
}

resource "proxmox_storage_lvmthin" "local_lvm" {
  id           = "local-lvm"
  volume_group = "pve"
  thin_pool    = "data"
  nodes        = ["nipogi"]
  content      = ["images", "rootdir"]
}
