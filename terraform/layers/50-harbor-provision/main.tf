
module "harbor_config" {
  source     = "../../modules/43-harbor-config"
  depends_on = [helm_release.harbor] # Should be after Harbor Helm Chart Pod Ready
}
