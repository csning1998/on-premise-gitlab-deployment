
output "foundation_topology" {
  description = "Topology of every service segment: identity, network, service segments, and the physical realization that bridges identity and service VIPs, all keyed by the SSoT identity."
  value       = module.foundation_libvirt_resources.topology
}

output "foundation_network_global" {
  description = "Global facts shared by every consumer: network baseline, root domain suffix, and the hostname to VIP records."
  value       = module.foundation_libvirt_resources.network_global
}

output "foundation_pki" {
  description = "PKI facts derived from the service catalog: the DNS SANs and organizational context per certificate."
  value       = module.foundation_libvirt_resources.pki
}

output "foundation_storage" {
  description = "Physical realization of the storage layout: the pools and data disks, and the calculated volume attributes."
  value       = module.foundation_libvirt_resources.storage
}

output "foundation_vault_path" {
  description = "Vault KV coordinates of the service catalog: the project_code segment, the folder of each component, the leaf paths below each component folder, and the SSH identity leaf keyed by cluster_name."
  value = {
    project_code     = local.foundation_project_code
    credential_paths = module.foundation_libvirt_resources.vault_path.credential_paths
    kv_paths         = local.foundation_kv_paths
    ssh_credential_paths = {
      for key, base in module.foundation_libvirt_resources.vault_path.ssh_credential_paths : key => "${base}/${local.kv_leaf.ssh}"
    }
  }
}

output "foundation_ssh" {
  description = "Local file paths of the SSH client material written by this layer, keyed by cluster_name. The known_hosts path is shared with the linux-generic-cluster instance of the same cluster_name."
  value = {
    identity_key_paths = module.ssh_identity_bootstrap.identity_key_private_paths
    public_key_paths   = module.ssh_identity_bootstrap.identity_key_public_paths
    config_paths       = module.ssh_identity_bootstrap.host_config_paths
    known_hosts_paths  = module.ssh_identity_bootstrap.known_hosts_paths
    usernames          = { for key, host in module.foundation_libvirt_resources.ssh_identity.hosts : key => host.nodes[0].user if host.enabled && length(host.nodes) > 0 }
  }
}

# Base images come from platform-foundation, while the Gitaly and Praefect image is built in this repository.
output "foundation_paths" {
  description = "Absolute paths of the repository directories which the layers hand to modules. The paths resolve on the host which applies this layer, as the paths of foundation_ssh do."
  value = {
    ansible_root           = abspath("${path.root}/../../../ansible")
    scripts_root           = abspath("${path.root}/../../../scripts")
    packer_output          = abspath("${path.root}/../../../packer/output")
    platform_packer_output = abspath("${path.root}/../../../../platform-foundation/packer/output")
  }
}
