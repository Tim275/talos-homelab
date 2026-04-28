variable "proxmox" {
  description = "Proxmox provider configuration"
  type = object({
    name         = string
    cluster_name = string
    endpoint     = string
    insecure     = bool
    username     = string
  })
}

variable "proxmox_api_token" {
  description = "API token for Proxmox"
  type        = string
  sensitive   = true
}

variable "talos_image" {
  description = "Talos image configuration"
  type = object({
    factory_url           = optional(string, "https://factory.talos.dev")
    version               = string
    schematic_path        = string
    update_version        = optional(string)
    update_schematic_path = optional(string)
    arch                  = optional(string, "amd64")
    platform              = optional(string, "nocloud")
    proxmox_datastore     = optional(string, "local")
  })
}

variable "talos_cluster_config" {
  description = "Talos cluster configuration"
  type = object({
    name                         = string
    vip                          = optional(string)
    gateway                      = string
    subnet_mask                  = optional(string, "24")
    talos_machine_config_version = optional(string)
    proxmox_cluster              = string
    kubernetes_version           = string
    gateway_api_version          = string
    extra_manifests              = optional(list(string), [])
    kubelet                      = optional(string)
    api_server                   = optional(string)
    cilium = object({
      bootstrap_manifest_path = string
      values_file_path        = string
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
    dns              = optional(list(string))
    update           = optional(bool, false)
    igpu             = optional(bool, false)
    os_disk_size     = optional(number, 50)   # OS disk size in GB
    ceph_disk_size   = optional(number, 0)    # Ceph OSD disk size in GB (0 = no Ceph disk)
  }))

  validation {
    condition     = length([for n in var.talos_nodes : n if contains(["controlplane", "worker"], n.machine_type)]) == length(var.talos_nodes)
    error_message = "Node machine_type must be either 'controlplane' or 'worker'."
  }
}

variable "sealed_secrets_config" {
  description = "Sealed secrets certificate configuration"
  type = object({
    certificate_path     = string
    certificate_key_path = string
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