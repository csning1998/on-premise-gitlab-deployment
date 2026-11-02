
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
  namespace_id = tonumber(local.gitlab_subgroup_ids["platform-engineering-lab"])

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
    issuer_id       = local.ai_provider["anthropic"].issuer_id
    organization_id = local.ai_provider["anthropic"].organization_id
  }

  google_federation = {
    project_id     = local.ai_provider["google-cloud"].project_id
    project_number = local.ai_provider["google-cloud"].project_number
    pool_id        = local.ai_provider["google-cloud"].pool_id
    provider_id    = local.ai_provider["google-cloud"].provider_id
  }

  azure_federation = {
    tenant_id            = local.ai_provider["azure"].tenant_id
    subscription_id      = local.ai_provider["azure"].subscription_id
    cognitive_account_id = local.ai_provider["azure"].cognitive_account_id
    openai_endpoint      = local.ai_provider["azure"].openai_endpoint
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
