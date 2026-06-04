
output "lb_cluster_vm_config" {
  description = "Fully resolved VM config with pre-computed interfaces, ready for hypervisor-kvm-lb."
  value       = local.lb_cluster_vm_config
}

output "lb_cluster_network_config" {
  description = "CLB own segment network config in hypervisor-kvm-lb format."
  value       = local.lb_cluster_network_config
}

output "nodes_list_for_ssh" {
  description = "Flat list of {key, ip} pairs for ssh-manager consumption."
  value       = local.nodes_list_for_ssh
}
