variable "rook_version" {
  description = "Rook operator version"
  type        = string
  default     = "v1.15.8"
}

variable "ceph_version" {
  description = "Ceph version to deploy"
  type        = string
  default     = "18.2.4"
}

variable "cluster_name" {
  description = "Name of the Ceph cluster"
  type        = string
  default     = "rook-ceph"
}

variable "mon_count" {
  description = "Number of Ceph monitors"
  type        = number
  default     = 3
  
  validation {
    condition     = var.mon_count % 2 == 1 && var.mon_count >= 3
    error_message = "Monitor count must be an odd number >= 3 for quorum"
  }
}

variable "replication_factor" {
  description = "Data replication factor"
  type        = number
  default     = 3
  
  validation {
    condition     = var.replication_factor >= 2 && var.replication_factor <= 5
    error_message = "Replication factor must be between 2 and 5"
  }
}

variable "enable_monitoring" {
  description = "Enable Prometheus monitoring"
  type        = bool
  default     = true
}

variable "enable_dashboard" {
  description = "Enable Ceph dashboard"
  type        = bool
  default     = true
}

variable "storage_nodes" {
  description = "Storage node configuration"
  type = list(object({
    name = string
    devices = list(object({
      name = string
    }))
  }))
  default = [
    {
      name = "work-01"
      devices = [{ name = "sdb" }]
    },
    {
      name = "work-03"
      devices = [{ name = "sdb" }]
    },
    {
      name = "work-05"
      devices = [{ name = "sdb" }]
    }
  ]
}

variable "resource_limits" {
  description = "Resource limits for Ceph components"
  type = object({
    mgr = object({
      cpu    = string
      memory = string
    })
    mon = object({
      cpu    = string
      memory = string
    })
    osd = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    mgr = {
      cpu    = "1000m"
      memory = "2Gi"
    }
    mon = {
      cpu    = "1000m"
      memory = "2Gi"
    }
    osd = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
}

variable "node_selector" {
  description = "Node selector for Rook operator"
  type        = map(string)
  default     = {}
}