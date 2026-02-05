
resource "helm_release" "local_path_provisioner" {
  name       = "local-path-storage"
  repository = "https://charts.containeroo.ch"
  chart      = "local-path-provisioner"
  version    = "0.0.35"
  namespace  = "kube-system"

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
    }
  ]
}
