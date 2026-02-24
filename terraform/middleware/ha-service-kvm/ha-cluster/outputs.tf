
locals {
  kvm_module_ref = var.use_minio_hypervisor ? module.hypervisor_kvm_minio[0] : module.hypervisor_kvm[0]
}

output "cluster_nodes" {
  description = "The physical KVM nodes provisioned for this cluster."
  value       = local.kvm_module_ref.provisioned_nodes
}

output "network_bindings" {
  description = "L2 network identity mapping (Sourced from KVM)."
  value = {
    for tier, config in local.kvm_module_ref.infrastructure_config : tier => {
      nat_net_name         = config.network.nat.name_network
      nat_bridge_name      = config.network.nat.name_bridge
      hostonly_net_name    = config.network.hostonly.name_network
      hostonly_bridge_name = config.network.hostonly.name_bridge
    }
  }
}

output "network_parameters" {
  description = "L3 network configurations (Sourced from KVM)."
  value = {
    for tier, config in local.kvm_module_ref.infrastructure_config : tier => {
      network = {
        nat = {
          cidrv4  = "${config.network.nat.ips.address}/${config.network.nat.ips.prefix}"
          gateway = config.network.nat.ips.address
          dhcp    = config.network.nat.ips.dhcp
        }
        hostonly = {
          cidrv4  = "${config.network.hostonly.ips.address}/${config.network.hostonly.ips.prefix}"
          gateway = config.network.hostonly.ips.address
        }
      }
      # Access Scope belongs to logic layer and this is not passed to KVM module.
      network_access_scope = var.network_parameters[tier].network_access_scope
    }
  }
}
