
module "ansible_sync_oci" {
  source = "../../modules/cluster-provision/ansible-runner"

  depends_on = [
    vault_kv_secret_v2.robot_helm_creds,
    harbor_project.proxy_oci,
    harbor_project.proxy_projects,
    harbor_registry.proxy_registries
  ]

  status_trigger = local.state.harbor_bootstrapper.topology_node
  ansible_config = local.ansible_config
  inventory_data = local.inventory_data
  credentials_vm = local.credentials_vm
  extra_vars     = local.ansible_extra_vars
}
