
output "vault_ha_virtual_ip" {
  description = "The VIP of the Vault HA Cluster"
  value       = var.vault_compute.haproxy_config.virtual_ip
}

output "vault_ca_cert" {
  description = "The Root CA Certificate content (Public Key) of the Vault Cluster"
  value       = module.vault_tls_gen.ca_cert_pem
  sensitive   = false
}

output "internal_pki_ca_cert" {
  description = "The CA Certificate used for Internal Services (Redis/Postgres)"
  value       = module.vault_pki_setup.pki_root_ca_certificate
}

output "pki_configuration" {
  description = "Centralized PKI configuration containing Role Names and Allowed Domains"
  value = {
    vault_pki_path = module.vault_pki_setup.vault_pki_path

    # Part A: Role Names for Vault Agent / Cert-Manager
    postgres_roles = module.vault_pki_setup.postgres_role_names
    redis_roles    = module.vault_pki_setup.redis_role_names
    minio_roles    = module.vault_pki_setup.minio_role_names

    ingress_roles = {
      dev_harbor = module.vault_pki_setup.dev_harbor_ingress_role_name
      harbor     = module.vault_pki_setup.harbor_ingress_role_name
      gitlab     = module.vault_pki_setup.gitlab_ingress_role_name
    }

    # Part B: Allowed Domains for App Config / Ingress
    postgres_domains = module.vault_pki_setup.postgres_role_domains
    redis_domains    = module.vault_pki_setup.redis_role_domains
    minio_domains    = module.vault_pki_setup.minio_role_domains

    ingress_domains = {
      dev_harbor = module.vault_pki_setup.dev_harbor_ingress_domains
      harbor     = module.vault_pki_setup.harbor_ingress_domains
      gitlab     = module.vault_pki_setup.gitlab_ingress_domains
    }
  }
}
