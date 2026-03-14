
variable "pod_subnet" {
  type        = string
  description = "The CIDR block for the Kubernetes pod network."
}

variable "image_registry" {
  type        = string
  description = "The container registry to pull images from (e.g. harbor.iac.local)"
  default     = "quay.io"
}

variable "image_path" {
  type        = string
  description = "The image path/project within the registry"
  default     = null
}
