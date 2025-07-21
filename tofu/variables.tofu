variable "proxmox" {
  type = object({
    name         = string
    cluster_name = string
    endpoint     = string
    insecure     = bool
    username     = string
    api_token    = string
  })
  sensitive = true
}

variable "talos_image" {
  description = "Talos image configuration"
  type = object({
    factory_url           = optional(string, "https://factory.talos.dev")
    schematic             = string
    version               = string
    update_schematic      = optional(string)
    update_version        = optional(string)
    arch                  = optional(string, "amd64")
    platform              = optional(string, "nocloud")
    proxmox_datastore     = optional(string, "local")
    talos_machine_config_version = optional(string)
  })
}

variable "talos_cluster_config" {
  description = "Cluster configuration"
  type = object({
    name            = string
    endpoint        = string
    vip             = optional(string)
    gateway         = string
    subnet_mask     = string
    talos_version   = string
    proxmox_cluster = string
    gateway_api_version = optional(string, "v1.1.0")
    extra_manifests = optional(list(string), [])
    api_server      = optional(string, "")
    cilium = object({
      bootstrap_manifest_path = string
      values_file_path       = string
    })
  })
}

variable "talos_nodes" {
  description = "Configuration for cluster nodes"
  type = map(object({
    host_node        = string
    machine_type     = string
    datastore_id     = optional(string, "local-zfs")
    ip               = string
    mac_address      = string
    vm_id            = number
    cpu              = number
    ram_dedicated    = number
    update           = optional(bool, false)
    igpu             = optional(bool, false)
  }))
}

variable "sealed_secrets_config" {
  description = "Sealed secrets certificate configuration"
  type = object({
    cert = string
    key  = string
  })
  sensitive = true
}

variable "kubernetes_volumes" {
  description = "Kubernetes volumes configuration"
  type = map(
    object({
      node    = string
      size    = string
      storage = optional(string, "local-zfs")
      vmid    = optional(number, 9999)
      format  = optional(string, "raw")
    })
  )
  default = {}
}