resource "kubernetes_namespace" "sealed-secrets" {
  metadata {
    name = "sealed-secrets"
  }
}

resource "kubernetes_secret" "sealed-secrets-key" {
  depends_on = [kubernetes_namespace.sealed-secrets]
  type       = "kubernetes.io/tls"

  metadata {
    name      = "sealed-secrets-bootstrap-key"
    namespace = "sealed-secrets"
    labels = {
      "sealedsecrets.bitnami.com/sealed-secrets-key" = "active"
    }
  }

  data = {
    "tls.crt" = file("${path.root}/${var.cert.certificate_path}")
    "tls.key" = file("${path.root}/${var.cert.certificate_key_path}")
  }
}

# After writing the bootstrap key, restart the controller so it picks up the
# correct key instead of the auto-generated one it created on first start.
resource "null_resource" "sealed_secrets_controller_restart" {
  depends_on = [kubernetes_secret.sealed-secrets-key]

  triggers = {
    cert_hash = sha256(file("${path.root}/${var.cert.certificate_path}"))
  }

  provisioner "local-exec" {
    command = "kubectl rollout restart deployment/sealed-secrets-controller -n sealed-secrets && kubectl rollout status deployment/sealed-secrets-controller -n sealed-secrets --timeout=120s"
  }
}