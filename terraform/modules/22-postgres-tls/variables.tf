
variable "server_ips" {
  description = "List of IP addresses to be included in the Server Certificate SANs (Node IPs + VIP + Loopback)"
  type        = list(string)
}

variable "server_dns_names" {
  description = "List of DNS names to be included in the Server Certificate SANs"
  type        = list(string)
  default     = ["postgres.iac.local", "localhost"]
}

variable "common_name" {
  description = "Common Name (CN) for the Server Certificate"
  type        = string
  default     = "postgres.iac.local"
}

variable "client_common_name" {
  description = "Common Name (CN) for the Client Certificate"
  type        = string
  default     = "harbor-client"
}

variable "rsa_bits" {
  description = "Number of bits for the RSA private key"
  type        = number
  default     = 4096
}

variable "validity_period" {
  description = "Validity period for the certificate in days"
  type        = number
  default     = 87600 # 3 years
}

variable "organization" {
  description = "The organization for the certificate"
  type        = string
  default     = "on-premise-gitlab-deployment"
}

variable "common_name_subject" {
  description = "The Common Name for the certificate"
  type        = string
  default     = "Postgres Root CA"
}
