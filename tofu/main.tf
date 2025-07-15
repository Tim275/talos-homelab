module "talos" {
  source = "./talos"

  providers = {
    proxmox = proxmox
  }

  image = {
    version = "v1.7.5"
    schematic = file("${path.module}/talos/image/schematic.yaml")
  }

  cilium = {
    install = file("${path.module}/talos/inline-manifests/cilium-install.yaml")
    values = file("${path.module}/../kubernetes/cilium/values.yaml")
  }

  cluster = {
  name            = "talos"
  endpoint        = "192.168.68.101"   # IP deiner ersten Control-Plane-VM (z.B. ctrl-00)
  gateway         = "192.168.68.1"     # Gateway aus deinem Netz
  talos_version   = "v1.7"
  proxmox_cluster = "homelab"
}

  nodes = {
    "ctrl-00" = {
      host_node     = "homelab"
      machine_type  = "controlplane"
      ip            = "192.168.68.101"
      mac_address   = "BC:24:11:2E:C8:A0"
      vm_id         = 800
      cpu           = 2
      ram_dedicated = 4144
      datastore_id  = "local-zfs"
    }
    "ctrl-01" = {
      host_node     = "homelab"
      machine_type  = "controlplane"
      ip            = "192.168.68.102"
      mac_address   = "BC:24:11:2E:C8:A1"
      vm_id         = 801
      cpu           = 2
      ram_dedicated = 4144
      datastore_id  = "local-zfs"
    }
    "work-00" = {
      host_node     = "homelab"
      machine_type  = "worker"
      ip            = "192.168.68.103"
      mac_address   = "BC:24:11:2E:C8:A2"
      vm_id         = 810
      cpu           = 2
      ram_dedicated = 12384
      datastore_id  = "local-zfs"
    }
    "work-01" = {
      host_node     = "homelab"
      machine_type  = "worker"
      ip            = "192.168.68.104"
      mac_address   = "BC:24:11:2E:C8:A3"
      vm_id         = 811
      cpu           = 2
      ram_dedicated = 6192
      datastore_id  = "local-zfs"
    }
  }
}