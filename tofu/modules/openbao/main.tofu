resource "kubernetes_namespace_v1" "openbao" {
  metadata {
    name = "openbao"
  }

  # Labels setzt Argo CD (base/namespace.yaml)
  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}
