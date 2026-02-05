
locals {
  root_domain = var.root_domain

  platforms = toset(["gitlab", "harbor"])

  dev_harbor_ingress_domains = [
    "dev-harbor.${local.root_domain}",
    "notary.dev-harbor.${local.root_domain}",
  ]

  harbor_ingress_domains = [
    "harbor.${local.root_domain}",
    "notary.harbor.${local.root_domain}",
  ]

  gitlab_ingress_domains = [
    "gitlab.${local.root_domain}",
    "kas.gitlab.${local.root_domain}",
    "registry.gitlab.${local.root_domain}",
    "minio.gitlab.${local.root_domain}"
  ]
}
