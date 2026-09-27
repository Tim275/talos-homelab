resource "kubernetes_namespace_v1" "openbao" {
  metadata {
    name = "openbao"
  }
}

resource "kubernetes_secret_v1" "seal-key" {
  depends_on = [kubernetes_namespace_v1.openbao]

  metadata {
    name      = "openbao-seal-key"
    namespace = "openbao"
  }

  data = {
    "BAO_SEAL_KEY" = var.seal != null ? trimspace(file("${path.root}/${var.seal.seal_key_path}")) : ""
  }

  # CI hat den key nicht
  lifecycle {
    ignore_changes = [data]
  }
}
