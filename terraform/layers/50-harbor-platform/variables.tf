
variable "harbor_hostname" {
  description = "The FQDN for Harbor access"
  type        = string
  default     = "harbor.iac.local" # mod in tfvars in future.
}

variable "microk8s_api_port" {
  description = "MicroK8s API Port"
  type        = string
  default     = "16443"
}
