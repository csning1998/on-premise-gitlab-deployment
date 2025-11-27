data "terraform_remote_state" "cluster_provision" {
  backend = "local"
  config = {
    path = "../10-provision-kubeadm/terraform.tfstate"
  }
}
