
locals {
  dns_hosts = {
    # Harbor Ingress VIP (Self)
    "${data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_virtual_ip}" = "harbor.iac.local notary.harbor.iac.local"

    # Infrastructure VIPs (External Services)
    "${data.terraform_remote_state.postgres.outputs.harbor_postgres_virtual_ip}" = "postgres.iac.local ${data.terraform_remote_state.vault_core.outputs.pki_configuration.postgres_domains["harbor"][0]}"

    "${data.terraform_remote_state.redis.outputs.harbor_redis_virtual_ip}" = "redis.iac.local ${data.terraform_remote_state.vault_core.outputs.pki_configuration.redis_domains["harbor"][0]}"

    "${data.terraform_remote_state.minio.outputs.harbor_minio_virtual_ip}" = "s3.iac.local ${data.terraform_remote_state.vault_core.outputs.pki_configuration.minio_domains["harbor"][0]}"

    "${data.terraform_remote_state.vault_core.outputs.vault_ha_virtual_ip}" = "vault.iac.local"
  }
}

locals {
  # Kubernetes Physical IP
  microk8s_physical_ip = data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_ip_list[0]
}

locals {
  kubeconfig_raw = data.terraform_remote_state.microk8s_provision.outputs.kubeconfig_content
  kubeconfig     = yamldecode(local.kubeconfig_raw)

  cluster_info = local.kubeconfig.clusters[0].cluster
  user_info    = local.kubeconfig.users[0].user
}
