
resource "vault_pki_secret_backend_cert" "haproxy_stats" {
  backend     = data.terraform_remote_state.vault_bootstrapper.outputs.bootstrap_pki_mount_path
  name        = "central-lb-frontend"
  common_name = local.state.metadata.global_pki_map["central-lb-frontend"].dns_san[0]

  alt_names = local.state.metadata.global_pki_map["central-lb-frontend"].dns_san
  ip_sans   = local.central_lb_node_ips
}
