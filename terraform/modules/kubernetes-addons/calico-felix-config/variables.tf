
variable "remove_external_routes" {
  description = "Whether Calico Felix removes externally managed routes. Keep false to preserve VIP static routes."
  type        = bool
  default     = false
}
