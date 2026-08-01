
output "proxy_caches" {
  description = "The Declared Harbor Projects for storing container images."
  value       = local.proxy_caches
}

output "proxy_oci" {
  description = "The Declared Harbor Projects for storing OCI images."
  value       = local.proxy_oci
}

output "service_vip" {
  description = "The virtual IP assigned to the Bootstrap Harbor service from Central LB topology."
  value       = data.terraform_remote_state.harbor_bootstrapper.outputs.service_vip
}

output "harbor_registry_fqdn" {
  value = local.state.harbor_bootstrapper.harbor_bootstrapper_fqdn
}

output "node_exporter_targets" {
  description = "Node Exporter scrape target for the Harbor Bootstrapper node."
  value       = local.state.harbor_bootstrapper.node_exporter_targets
}

output "helm_pusher_robot_username" {
  value = harbor_robot_account.helm_pusher.full_name
}
