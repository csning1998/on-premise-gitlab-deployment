data "terraform_remote_state" "cluster_provision" {
  backend = "local"
  config = {
    path = "../60-gitlab-kubeadm/terraform.tfstate"
  }
}
