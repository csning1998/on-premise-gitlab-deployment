
output "node_exporter_targets" {
  description = "Node Exporter scrape target for the Keycloak node."
  value = {
    ips  = module.context.svc_network.node_ips
    port = module.context.node_exporter_port
  }
}
