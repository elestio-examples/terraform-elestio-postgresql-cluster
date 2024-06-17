output "nodes" {
  description = "The primary and replicas nodes output."
  value = {
    primary = local.primary_node
    replicas = {
      for node in local.replicas_nodes : node.server_name => node
    }
  }
  sensitive = true
}
