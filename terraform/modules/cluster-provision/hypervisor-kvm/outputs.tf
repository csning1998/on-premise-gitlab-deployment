
output "provisioned_nodes" {
  description = "Map of provisioned KVM nodes with their actual state."
  value = {
    for key, domain in libvirt_domain.nodes : key => {
      ip                   = var.guest_config.all_nodes_map[key].ip
      id                   = domain.id
      name                 = domain.name
      vcpu                 = domain.vcpu
      ram_size_mib         = domain.memory
      os_disk_capacity_gib = var.guest_config.all_nodes_map[key].os_disk_capacity_gib
      attached_volumes     = var.guest_config.all_nodes_map[key].attached_volumes
    }
  }
}

output "infrastructure_config" {
  description = "The actual infrastructure configuration used by Libvirt."
  value       = var.libvirt_infrastructure
}

output "guest_status_trigger" {
  description = "A trigger to indicate completion of VM provisioning"
  value       = { for key, domain in libvirt_domain.nodes : key => domain.id }
}
