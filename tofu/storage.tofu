# local-zfs hatte als einziger Storage keine nodes-Zeile; pve hat kein rpool und
# lief deshalb alle 10s in "cannot import 'rpool'" -> pvestatd blockiert -> Watchdog-Reset
resource "proxmox_storage_zfspool" "local_zfs" {
  id             = "local-zfs"
  zfs_pool       = "rpool"
  nodes          = ["nipogi", "msa2proxmox"]
  content        = ["images", "rootdir"]
  thin_provision = true
}

import {
  to = proxmox_storage_zfspool.local_zfs
  id = "local-zfs"
}
