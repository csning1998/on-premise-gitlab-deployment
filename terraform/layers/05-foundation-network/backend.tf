
# Local backend — this state file is long-lived and should never be auto-deleted
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
