
locals {
  root_domain = var.root_domain

  platforms = toset(["gitlab", "harbor"])

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
