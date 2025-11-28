data "terraform_remote_state" "cluster_provision" {
  backend = "local"
  config = {
    path = "../50-provision-kubeadm-gitlab/terraform.tfstate"
  }
}
