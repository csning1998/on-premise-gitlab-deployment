
module "context" {
  source = "../../modules/layer-context"

  global_topology_identity = data.terraform_remote_state.metadata.outputs.global_topology_identity
  global_topology_network  = data.terraform_remote_state.metadata.outputs.global_topology_network
  global_pki_map           = data.terraform_remote_state.metadata.outputs.global_pki_map
  global_network_baseline  = data.terraform_remote_state.metadata.outputs.global_network_baseline
  infrastructure_map       = data.terraform_remote_state.network.outputs.infrastructure_map
  vault_sys_vip            = data.terraform_remote_state.vault_sys.outputs.service_vip
  vault_pki_outputs        = data.terraform_remote_state.vault_pki.outputs
  guest_vm_data            = data.vault_generic_secret.guest_vm.data

  target_clusters = var.target_clusters
  primary_role    = var.primary_role
  service_config  = var.service_config
}

module "infra_harbor_redis" {
  source = "../../middleware/ha-service-kvm-general"

  svc_identity                  = module.context.svc_identity
  node_identities               = module.context.node_identities
  topology_cluster              = module.context.topology_cluster
  storage_infrastructure_map    = data.terraform_remote_state.volume.outputs.storage_infrastructure_map
  network_infrastructure_map    = module.context.network_infrastructure_map
  credentials_system            = module.context.sec_vm_creds
  security_vault_agent_identity = local.sec_vault_agent_identity

  ansible_generic_config = {
    template_vars = local.ansible_template_vars
    extra_vars    = local.ansible_extra_vars
  }
}
