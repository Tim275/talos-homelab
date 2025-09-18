# Envoy Gateway Bootstrap with Tofu/Terraform
# This replaces the problematic large YAML manifest approach

# 1. Download Envoy Gateway install.yaml
data "http" "envoy_gateway_manifest" {
  url = "https://github.com/envoyproxy/gateway/releases/download/v1.5.0/install.yaml"
}

# 2. Split and apply manifests using kubectl_manifest
locals {
  # Split the large YAML into individual documents
  envoy_gateway_manifests = [
    for doc in split("---", data.http.envoy_gateway_manifest.response_body) :
    trim(doc, " \t\n\r")
    if length(trim(doc, " \t\n\r")) > 0 && can(yamldecode(doc))
  ]
}

# 3. Apply each manifest separately (handles large files better)
resource "kubectl_manifest" "envoy_gateway" {
  for_each = {
    for idx, manifest in local.envoy_gateway_manifests :
    "${idx}-${try(yamldecode(manifest).kind, "unknown")}" => manifest
  }

  yaml_body = each.value
  server_side_apply = true

  # Handle dependencies
  depends_on = [
    kubernetes_namespace.envoy_gateway_system
  ]
}

# 4. Create namespace first
resource "kubernetes_namespace" "envoy_gateway_system" {
  metadata {
    name = "envoy-gateway-system"
    labels = {
      provisioned_by = "tofu"
      component      = "envoy-gateway"
    }
  }
}

# 5. Wait for Envoy Gateway to be ready
resource "kubectl_manifest" "envoy_gateway_class" {
  depends_on = [kubectl_manifest.envoy_gateway]

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name = "envoy-gateway"
    }
    spec = {
      controllerName = "gateway.envoyproxy.io/gatewayclass-controller"
    }
  })
}

# 6. Output Gateway status
output "envoy_gateway_status" {
  value = "Envoy Gateway v1.5.0 bootstrapped via Tofu"
}