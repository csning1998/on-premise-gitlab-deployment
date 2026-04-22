
variable "ingress_vip" {
  description = "The static IP address (VIP) for the Ingress Controller LoadBalancer"
  type        = string
}

variable "ingress_class_name" {
  description = "The name of the ingress class"
  type        = string
  default     = "nginx"
}

variable "image_registry" {
  description = "The container image registry to pull OCI Helm charts from"
  type        = string
}

variable "chart_project" {
  description = "The project name in Harbor for Helm charts"
  type        = string
}
