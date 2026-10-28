
# The project code is the identity of this repository: the GitLab project, the WIF owner code, and the GitHub mirror share the project code.
locals {
  project_code = "on-premise-gitlab-deployment"
}

module "provisioner_gitlab_project" {
  source  = "gitlab.com/csning1998-lab/provisioner-gitlab-project/gitlab"
  version = "0.2.0"

  name         = local.project_code
  description  = "Multi-layer Terraform IaC for the on-premise GitLab and Harbor deployment on KVM/QEMU (Libvirt), provisioned end-to-end via Packer, Terraform, and Ansible."
  visibility   = "public"
  namespace_id = local.state.group_topology.subgroup_ids["platform-engineering-lab"]

  only_allow_merge_if_pipeline_succeeds = true
}

module "workload_identity_federation" {
  source  = "gitlab.com/csning1998-lab/provisioner-workload-identity-federation/gitlab"
  version = "0.5.0"

  gitlab_project = {
    id   = module.provisioner_gitlab_project.project_id
    path = module.provisioner_gitlab_project.full_path
    code = local.project_code
  }

  anthropic_federation = {
    issuer_id       = local.state.group_federation_anthropic.issuers.gitlab_saas.id
    organization_id = local.state.group_federation_anthropic.organization.id
  }

  google_federation = {
    project_id     = local.state.group_federation_gcp.project.id
    project_number = local.state.group_federation_gcp.project.number
    pool_id        = local.state.group_federation_gcp.pool.id
    provider_id    = local.state.group_federation_gcp.provider.id
  }

  azure_federation = {
    tenant_id            = local.state.group_federation_azure.tenant.id
    subscription_id      = local.state.group_federation_azure.subscription.id
    cognitive_account_id = local.state.group_federation_azure.openai.id
    openai_endpoint      = local.state.group_federation_azure.openai.endpoint
    subjects = [
      "project_path:${module.provisioner_gitlab_project.full_path}:ref_type:branch:ref:main",
    ]
  }
}

module "code_reviewer" {
  source    = "gitlab.com/csning1998-lab/provisioner-code-reviewer/gitlab"
  version   = "~> 1.7.1"
  providers = { vault = vault.bastion }

  gitlab_project_id    = module.provisioner_gitlab_project.project_id
  legacy_alias_enabled = true
}

module "github_mirror" {
  source  = "gitlab.com/csning1998-lab/provisioner-github-mirror/gitlab"
  version = "0.3.1"

  gitlab_project_id = module.provisioner_gitlab_project.project_id

  github_repository = {
    name  = local.project_code
    owner = var.github_owner
  }
}
