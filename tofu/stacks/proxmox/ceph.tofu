locals {
  ceph_pools = {
    "replicapool-enterprise"     = { application = "rbd", crush_rule = "ssd-osd", pg_num = 32 }
    "kafka-fast"                 = { application = "rbd", crush_rule = "ssd-osd", pg_num = 32 }
    "obs-pool"                   = { application = "rbd", crush_rule = "ssd-osd", pg_num = 32 }
    "default.rgw.log"            = { application = "rgw", crush_rule = "ssd-osd", pg_num = 8 }
    "default.rgw.control"        = { application = "rgw", crush_rule = "ssd-osd", pg_num = 8 }
    "default.rgw.meta"           = { application = "rgw", crush_rule = "ssd-osd", pg_num = 8 }
    "default.rgw.buckets.index"  = { application = "rgw", crush_rule = "ssd-osd", pg_num = 8 }
    "default.rgw.buckets.non-ec" = { application = "rgw", crush_rule = "ssd-osd", pg_num = 8 }
    "default.rgw.buckets.data"   = { application = "rgw", crush_rule = "hdd-osd", pg_num = 32 }
  }
}

# size 3 auf je einer Platte pro Klasse: Muster, kein Schutz vor Plattenausfall
resource "proxmox_ceph_pool" "this" {
  for_each = local.ceph_pools

  node_name         = "aoostar"
  name              = each.key
  application       = each.value.application
  crush_rule        = each.value.crush_rule
  size              = 3
  min_size          = 2
  pg_num            = each.value.pg_num
  pg_autoscale_mode = "on"
}
