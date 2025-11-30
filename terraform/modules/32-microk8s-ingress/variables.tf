
variable "ingress_vip" {
  description = "The static IP address (VIP) for the Ingress Controller LoadBalancer"
  type        = string
}

variable "ingress_class_name" {
  description = "The name of the ingress class"
  type        = string
  default     = "nginx"
}
