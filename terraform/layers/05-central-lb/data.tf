
data "terraform_remote_state" "topology" {
  backend = "local"
  config = {
    path = "${path.root}/../00-global-topology/terraform.tfstate"
  }
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "${path.root}/../04-network-topology/terraform.tfstate"
  }
}
