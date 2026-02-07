
variable "hosts" {
  description = "A map of IP to Hostnames to inject into CoreDNS"
  type        = map(string)
  default     = {}
}

variable "cluster_domain" {
  description = "Kubernetes cluster domain"
  type        = string
  default     = "cluster.local"
}

variable "custom_corefile" {
  description = "Optional custom Corefile content. If not provided, a default template is used."
  type        = string
  default     = null
}
