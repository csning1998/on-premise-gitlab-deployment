
# Role: Harbor Ingress
resource "vault_pki_secret_backend_role" "gitlab_ingress" {
  backend = vault_mount.pki_prod.path
  name    = "gitlab-ingress-role"

  allowed_domains = local.gitlab_ingress_domains

  allow_subdomains   = true
  allow_glob_domains = false
  allow_ip_sans      = true
  allow_bare_domains = true

  key_usage = [
    "DigitalSignature",
    "KeyEncipherment",
    "KeyAgreement"
  ]

  server_flag = true # Server Flag for Ingress HTTPS
  client_flag = true # Client Flag for GitLab Rails to connect Postgres/Redis mTLS

  max_ttl = 2592000 # 30 Days
  ttl     = 86400   # 24 Hours

  allow_any_name    = false
  enforce_hostnames = true
}

# Policy: Allow usage of the GitLab Role. This will be bind to Cert-Manager in ServiceAccount of Kubeadm
resource "vault_policy" "gitlab_pki" {
  name = "gitlab-pki-policy"

  # 1. Allow the path pki/prod/sign/gitlab-ingress-role to sign certificate
  # 2. Allow to sign and issue certificate for GitLab Ingress
  # 3. Allow to read CRL
  policy = <<EOT
path "${vault_mount.pki_prod.path}/sign/gitlab-ingress-role" {
  capabilities = ["create", "update"]
}

path "${vault_mount.pki_prod.path}/issue/gitlab-ingress-role" {
  capabilities = ["create", "update"]
}

path "${vault_mount.pki_prod.path}/crl" {
  capabilities = ["read"]
}
EOT
}
