resource "kubernetes_namespace_v1" "openbao" {
  metadata {
    name = "openbao"
  }

  # Labels setzt Argo CD (base/namespace.yaml)
  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "kubernetes_secret_v1" "unseal_azure" {
  depends_on = [kubernetes_namespace_v1.openbao]

  metadata {
    name      = "openbao-unseal-azure"
    namespace = "openbao"
    labels = {
      "velero.io/exclude-from-backup" = "true"
    }
  }

  data = var.unseal
}

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "kubernetes_secret_v1" "bootstrap_values" {
  depends_on = [kubernetes_namespace_v1.external_secrets]

  metadata {
    name      = "openbao-bootstrap-values"
    namespace = "external-secrets"
    labels = {
      "velero.io/exclude-from-backup" = "true"
    }
  }

  data = var.values

  # CI hat die Werte nicht
  lifecycle {
    ignore_changes = [data]
  }
}
