
output "service_node_ports" {
  description = "NodePort mappings for the Ingress NGINX controller service."
  value = (var.helm_config.install && length(data.kubernetes_service_v1.ingress_nginx_controller) > 0) ? {
    for port in data.kubernetes_service_v1.ingress_nginx_controller[0].spec[0].port : port.name => port.node_port
  } : {}
}
