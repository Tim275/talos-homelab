resource "kubernetes_labels" "node_roles" {
  for_each = { for k, v in var.talos_nodes : k => v if v.machine_type == "worker" }

  api_version = "v1"
  kind        = "Node"

  metadata {
    name = each.key
  }

  labels = merge(
    { "node-role.kubernetes.io/worker" = "" },
    each.value.pool != "" ? { "node-role.kubernetes.io/${each.value.pool}" = "" } : {}
  )

  depends_on = [module.talos]
}
