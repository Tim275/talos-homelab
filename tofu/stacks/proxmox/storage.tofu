import {
  to = proxmox_storage_zfspool.local_zfs
  id = "local-zfs"
}

resource "proxmox_storage_zfspool" "local_zfs" {
  id             = "local-zfs"
  zfs_pool       = "rpool/data"
  nodes          = ["msa2proxmox", "nipogi", "aoostar"]
  content        = ["images", "rootdir"]
  thin_provision = true
}
