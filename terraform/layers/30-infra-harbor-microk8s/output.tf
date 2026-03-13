
output "harbor_microk8s_ip_list" {
  description = "List of MicroK8s node IPs for Harbor"
  value       = [for k, v in local.topology_cluster.components["frontend"].nodes : cidrhost(local.net_microk8s.network.hostonly.cidr, v.ip_suffix)]
}

output "harbor_microk8s_virtual_ip" {
  description = "MicroK8s virtual IP for Harbor"
  value       = local.net_service_vip
}
