
locals {
  state = {
    group_federation_anthropic = data.terraform_remote_state.group_federation_anthropic.outputs
    group_federation_gcp       = data.terraform_remote_state.group_federation_gcp.outputs
    group_federation_azure     = data.terraform_remote_state.group_federation_azure.outputs
    group_topology             = data.terraform_remote_state.group_topology.outputs
  }
}

locals {
  _state_base_parent_group_governance = "https://gitlab.com/api/v4/projects/86417732/terraform/state"
}

ephemeral "vault_kv_secret_v2" "state_backend" {
  provider = vault.bastion
  mount    = "secret"
  name     = "parent-group-governance/terraform/state-backend"
}

ephemeral "vault_kv_secret_v2" "anthropic_admin_key" {
  provider = vault.bastion
  mount    = "secret"
  name     = "parent-group-governance/ai-provider-console/anthropic"
}

data "terraform_remote_state" "group_federation_anthropic" {
  backend = "http"
  config = {
    address = "${local._state_base_parent_group_governance}/group-federation-anthropic"
  }
}

data "terraform_remote_state" "group_federation_gcp" {
  backend = "http"
  config = {
    address = "${local._state_base_parent_group_governance}/group-federation-gcp"
  }
}

data "terraform_remote_state" "group_federation_azure" {
  backend = "http"
  config = {
    address = "${local._state_base_parent_group_governance}/group-federation-azure"
  }
}

data "terraform_remote_state" "group_topology" {
  backend = "http"
  config = {
    address = "${local._state_base_parent_group_governance}/group-topology"
  }
}
