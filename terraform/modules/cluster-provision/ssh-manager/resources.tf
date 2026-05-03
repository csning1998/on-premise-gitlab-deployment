terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

locals {
  cluster_name    = var.config_name.cluster_name
  ssh_config_name = var.config_name.ssh_config_name
  # Dynamically construct file paths based on the provided config_name
  ssh_config_path  = pathexpand("~/.ssh/${local.ssh_config_name}")
  known_hosts_path = pathexpand("~/.ssh/known_hosts_${local.cluster_name}")
}

/*
* Generate a ~/.ssh/on-premise-gitlab-deployment_config file in the user's home directory with an alias and a specified public key
* for passwordless SSH using the alias (e.g., ssh kubeadm-master-00).
*/
resource "local_file" "ssh_config" {

  content = templatefile("${path.module}/../../../templates/ssh_config.tftpl", {
    nodes                = var.nodes
    ssh_user             = var.credentials_vm.username
    ssh_private_key_path = var.credentials_vm.ssh_private_key_path
    config_name          = local.cluster_name
    known_hosts_path     = local.known_hosts_path
  })
  filename        = local.ssh_config_path
  file_permission = "0600"
}

/*
* NOTE: Call functions in `utils_ssh.sh` via local-exec to manage the ~/.ssh/config file. 
* This avoids deletion during `terraform destroy()` in `scripts/terraform.sh`.
*/
resource "null_resource" "ssh_config_include" {
  depends_on = [local_file.ssh_config]

  # Re-run when the content of the ssh_config changes
  triggers = {
    ssh_config_content = local_file.ssh_config.content
    config_path        = local.ssh_config_path
  }

  provisioner "local-exec" {
    command     = ". ${path.module}/../../../../scripts/utils_ssh.sh && ssh_config_bootstrapper ${self.triggers.config_path}"
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when        = destroy
    command     = ". ${path.module}/../../../../scripts/utils_ssh.sh && ssh_config_include_unbootstrapper ${self.triggers.config_path}"
    interpreter = ["/bin/bash", "-c"]
  }
}

/*
* This makes sure this resource runs only after the "for_each" loop
* in "configure_nodes" has completed for all nodes.
*/
resource "null_resource" "prepare_ssh_access" {

  depends_on = [null_resource.ssh_config_include]

  triggers = {
    # The ID of the VMs change when they are (re)established. 
    # This modifies jsonencode and thus trigger this resource, Also pass the known_hosts_path via a trigger.
    vm_provisioning_complete = jsonencode(var.status_trigger)
  }

  provisioner "local-exec" {
    command     = <<-EOT
      set -e
      . ${path.module}/../../../../scripts/utils_ssh.sh
      log_print "STEP" "Verifying VM liveness and preparing SSH access..."
      known_hosts_bootstrapper "${local.cluster_name}" ${join(" ", [for node in var.nodes : node.ip])}
      log_print "OK" "Liveness check passed. SSH access is ready."
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}
