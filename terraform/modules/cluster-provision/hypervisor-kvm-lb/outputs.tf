
output "all_nodes_map" {
  description = "List of all provisioned KVM nodes"
  value = [
    for key, node in libvirt_domain.nodes : {
      key = key
      ip = try(
        var.lb_cluster_vm_config.nodes[key].interfaces[1].addresses[0], # HostOnly
        var.lb_cluster_vm_config.nodes[key].interfaces[0].addresses[0], # NAT
        ""
      )

      ram  = var.lb_cluster_vm_config.nodes[key].ram
      vcpu = var.lb_cluster_vm_config.nodes[key].vcpu
      path = ""
    }
  ]
}

output "vm_status_trigger" {
  description = "A trigger to indicate completion of VM provisioning"
  value       = { for key, domain in libvirt_domain.nodes : key => domain.id }
}
