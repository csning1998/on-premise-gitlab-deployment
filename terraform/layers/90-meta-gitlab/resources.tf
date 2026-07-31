
module "baseline" {
  source  = var.baseline_module_source
  version = var.baseline_module_version

  name           = var.repository_name
  description    = var.repository_description
  visibility     = var.visibility
  namespace_id   = data.terraform_remote_state.group_topology.outputs.subgroup_ids["personal"]
  gemini_api_key = sensitive(data.terraform_remote_state.gemini_api_keys.outputs.gemini_api_keys["on-premise-gitlab-deployment"])
  claude_api_key = sensitive(data.terraform_remote_state.gemini_api_keys.outputs.claude_api_keys["on-premise-gitlab-deployment"])
}
