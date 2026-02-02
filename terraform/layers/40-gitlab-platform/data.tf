
data "terraform_remote_state" "cluster_provision" {
  backend = "local"
  config = {
    path = "../30-gitlab-kubeadm/terraform.tfstate"
  }
}
