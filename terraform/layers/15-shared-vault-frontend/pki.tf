
resource "vault_pki_secret_backend_cert" "vault_listener" {
  backend     = data.terraform_remote_state.vault_bootstrapper.outputs.bootstrap_pki_mount_path
  name        = "vault-frontend"
  common_name = module.context.svc_fqdn

  alt_names = concat(data.terraform_remote_state.metadata.outputs.global_pki_map["vault-frontend"].dns_san, ["vault", "localhost"])
  ip_sans = concat(
    ["127.0.0.1", module.context.primary_net_config.lb_config.vip],
    module.context.svc_network.node_ips
  )
}
