
resource "helm_release" "local_path_provisioner" {
  count = var.helm_config.install ? 1 : 0

  name             = "local-path-storage"
  repository       = "https://charts.containeroo.ch"
  chart            = "local-path-provisioner"
  version          = var.helm_config.version
  namespace        = var.helm_config.namespace
  create_namespace = var.helm_config.create_namespace

  set = [
    {
      name  = "storageClass.name"
      value = "local-path"
    },
    {
      name  = "storageClass.defaultClass"
      value = "true"
    },
    {
      name  = "nodePath"
      value = "/opt/local-path-provisioner"
    },
    {
      name  = "image.repository"
      value = "${var.helm_config.image_registry}/${var.helm_config.image_repository}/local-path-provisioner"
    },
    {
      name  = "helperImage.repository"
      value = "${var.helm_config.image_registry}/${var.helm_config.helper_image_repository}/busybox"
    }
  ]
}
