
output "provisioned_nodes" {
  description = "Map of provisioned KVM nodes with their actual state."
  value = {
    for key, domain in libvirt_domain.nodes : key => {
      ip   = var.vm_config.all_nodes_map[key].ip
      id   = domain.id
      name = domain.name
      vcpu = domain.vcpu
      ram  = domain.memory
    }
  }
}

output "infrastructure_config" {
  description = "The actual infrastructure configuration used by Libvirt."
  value       = var.libvirt_infrastructure
}



output "vm_status_trigger" {
  description = "A trigger to indicate completion of VM provisioning"
  value       = { for key, domain in libvirt_domain.nodes : key => domain.id }
}
