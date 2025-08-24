terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11.0"
    }
  }
}

# cert-manager Helm Release
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }

  set {
    name  = "prometheus.enabled"
    value = var.enable_monitoring
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Cloudflare API Token Secret
resource "kubernetes_secret" "cloudflare_api_token" {
  depends_on = [helm_release.cert_manager]

  metadata {
    name      = "cloudflare-api-token"
    namespace = var.issuer_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "cert-manager"
    }
  }

  data = {
    api-token = var.cloudflare_api_token
  }

  type = "Opaque"
}

# ClusterIssuer for Let's Encrypt Production
resource "kubernetes_manifest" "letsencrypt_issuer" {
  depends_on = [
    helm_release.cert_manager,
    kubernetes_secret.cloudflare_api_token
  ]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.issuer_name
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "cert-manager"
      }
    }
    spec = {
      acme = {
        server = var.acme_server
        email  = var.acme_email
        privateKeySecretRef = {
          name = "${var.issuer_name}-private-key"
        }
        solvers = [{
          dns01 = {
            cloudflare = {
              apiTokenSecretRef = {
                name = kubernetes_secret.cloudflare_api_token.metadata[0].name
                key  = "api-token"
              }
            }
          }
          selector = {
            dnsZones = var.dns_zones
          }
        }]
      }
    }
  }
}

# Gateway Namespace
resource "kubernetes_namespace" "gateway" {
  metadata {
    name = var.gateway_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "gateway"
    }
  }
}

# Wildcard Certificate
resource "kubernetes_manifest" "wildcard_certificate" {
  depends_on = [
    kubernetes_manifest.letsencrypt_issuer,
    kubernetes_namespace.gateway
  ]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = var.certificate_name
      namespace = kubernetes_namespace.gateway.metadata[0].name
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "cert-manager"
      }
    }
    spec = {
      secretName = var.certificate_secret_name
      issuerRef = {
        name = kubernetes_manifest.letsencrypt_issuer.manifest.metadata.name
        kind = "ClusterIssuer"
      }
      dnsNames = var.certificate_domains
      usages = [
        "digital signature",
        "key encipherment"
      ]
    }
  }
}

# Output the certificate secret for ingress use
output "certificate_secret_name" {
  description = "Name of the certificate secret"
  value       = kubernetes_manifest.wildcard_certificate.manifest.spec.secretName
}

output "certificate_namespace" {
  description = "Namespace of the certificate"
  value       = kubernetes_namespace.gateway.metadata[0].name
}