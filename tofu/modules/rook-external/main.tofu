locals {
  v = var.values != null ? var.values : {
    fsid                    = ""
    mon_data                = ""
    healthchecker_key       = ""
    csi_rbd_node_key        = ""
    csi_rbd_provisioner_key = ""
    rgw_admin_access_key    = ""
    rgw_admin_secret_key    = ""
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "rook-ceph"
  }

  # Labels setzt Argo CD (base/namespace.yaml)
  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "kubernetes_secret_v1" "mon" {
  metadata {
    name      = "rook-ceph-mon"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  type = "kubernetes.io/rook"

  data = {
    cluster-name  = "rook-ceph"
    fsid          = local.v.fsid
    admin-secret  = "admin-secret"
    mon-secret    = "mon-secret"
    ceph-username = "client.healthchecker"
    ceph-secret   = local.v.healthchecker_key
  }

  # CI hat die Werte nicht
  lifecycle {
    ignore_changes = [data]
  }
}

resource "kubernetes_config_map_v1" "mon_endpoints" {
  metadata {
    name      = "rook-ceph-mon-endpoints"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    data     = local.v.mon_data
    mapping  = "{}"
    maxMonId = "2"
  }

  # Rook pflegt die Mon-Liste selbst
  lifecycle {
    ignore_changes = [data]
  }
}

resource "kubernetes_secret_v1" "csi" {
  for_each = toset(["node", "provisioner"])

  metadata {
    name      = "rook-csi-rbd-${each.key}"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  type = "kubernetes.io/rook"

  data = {
    userID  = "csi-rbd-${each.key}"
    userKey = each.key == "node" ? local.v.csi_rbd_node_key : local.v.csi_rbd_provisioner_key
  }

  lifecycle {
    ignore_changes = [data]
  }
}

resource "kubernetes_secret_v1" "rgw_admin" {
  metadata {
    name      = "rgw-admin-ops-user"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  type = "kubernetes.io/rook"

  data = {
    accessKey = local.v.rgw_admin_access_key
    secretKey = local.v.rgw_admin_secret_key
  }

  lifecycle {
    ignore_changes = [data]
  }
}
