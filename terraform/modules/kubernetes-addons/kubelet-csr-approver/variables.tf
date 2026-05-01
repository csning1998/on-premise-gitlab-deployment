variable "helm_config" {
  description = "Configuration for the kubelet-csr-approver Helm release"
  type = object({
    install          = bool
    namespace        = string
    create_namespace = bool
    version          = string
    image_registry   = string
    chart_project    = string
    image_repository = string
    image_tag        = string
    provider_regex   = string
  })
}
