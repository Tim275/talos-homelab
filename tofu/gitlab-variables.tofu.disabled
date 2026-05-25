variable "gitlab_config" {
  description = "GitLab CE VM configuration"
  type = object({
    name                = string
    host_node           = string
    host_node_ip        = string
    vm_id               = number
    ip                  = string
    mac_address         = string
    gateway             = string
    cpu                 = number
    ram_dedicated       = number
    disk_size           = number
    datastore_id        = optional(string, "local-zfs")
    external_url        = string
    ssh_authorized_keys = list(string)
  })
}
