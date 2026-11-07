resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
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

  data = merge(var.values, {
    "monitoring.etcd-client-cert.ca.crt"     = var.etcd_client_cert.ca
    "monitoring.etcd-client-cert.server.crt" = var.etcd_client_cert.cert
    "monitoring.etcd-client-cert.server.key" = var.etcd_client_cert.key
  })

  # CI hat die Werte nicht
  lifecycle {
    ignore_changes = [data]
  }
}
