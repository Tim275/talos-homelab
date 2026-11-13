variable "values" {
  type = object({
    fsid                    = string
    mon_data                = string
    healthchecker_key       = string
    csi_rbd_node_key        = string
    csi_rbd_provisioner_key = string
    rgw_admin_access_key    = string
    rgw_admin_secret_key    = string
  })
  sensitive = true
}
