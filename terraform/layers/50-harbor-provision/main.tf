
module "harbor_system_config" {
  source     = "../../modules/configuration/harbor-system-config"
  depends_on = [helm_release.harbor] # Should be after Harbor Helm Chart Pod Ready
}
