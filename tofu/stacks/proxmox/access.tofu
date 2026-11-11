resource "proxmox_virtual_environment_role" "tofu" {
  role_id = "Tofu"
  privileges = [
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.AllocateTemplate",
    "Datastore.Audit",
    "Permissions.Modify",
    "Realm.AllocateUser",
    "SDN.Use",
    "Sys.Audit",
    "Sys.Modify",
    "User.Modify",
    "VM.Allocate",
    "VM.Audit",
    "VM.Config.CDROM",
    "VM.Config.CPU",
    "VM.Config.Cloudinit",
    "VM.Config.Disk",
    "VM.Config.HWType",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.Options",
    "VM.GuestAgent.Audit",
    "VM.PowerMgmt",
  ]
}

locals {
  # privsep-Token: wirksam ist nur, was User- und Token-ACL beide erlauben
  tokens = {
    talos = {
      user = "tofu@pve"
      role = proxmox_virtual_environment_role.tofu.role_id
    }
    monitoring = {
      user = "pve-exporter@pve"
      role = "PVEAuditor"
    }
  }
}

resource "proxmox_virtual_environment_user" "this" {
  for_each = local.tokens

  user_id = each.value.user
}

resource "proxmox_user_token" "this" {
  for_each = local.tokens

  user_id    = proxmox_virtual_environment_user.this[each.key].user_id
  token_name = each.key
}

resource "proxmox_acl" "user" {
  for_each = local.tokens

  user_id   = proxmox_virtual_environment_user.this[each.key].user_id
  role_id   = each.value.role
  path      = "/"
  propagate = true
}

resource "proxmox_acl" "token" {
  for_each = local.tokens

  token_id  = proxmox_user_token.this[each.key].id
  role_id   = each.value.role
  path      = "/"
  propagate = true
}

resource "proxmox_virtual_environment_cluster_firewall" "this" {
  enabled = false
}
