
# Redis Provisioning State for Harbor to get node IPs
data "terraform_remote_state" "redis_provision" {
  backend = "local"
  config = {
    path = "${path.module}/../25-provision-redis/terraform.tfstate"
  }
}
