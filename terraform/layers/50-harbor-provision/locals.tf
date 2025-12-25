
locals {
  kubeconfig_raw = data.terraform_remote_state.microk8s_provision.outputs.kubeconfig_content
  kubeconfig     = yamldecode(local.kubeconfig_raw)

  cluster_info     = local.kubeconfig.clusters[0].cluster
  user_info        = local.kubeconfig.users[0].user
  vm_username      = data.vault_generic_secret.variables.data["vm_username"]
  private_key_path = data.vault_generic_secret.variables.data["ssh_private_key_path"]
}
