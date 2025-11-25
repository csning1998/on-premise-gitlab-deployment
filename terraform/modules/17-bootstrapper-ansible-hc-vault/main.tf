terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

/*
* Generate the Ansible inventory file from template
*/
resource "local_file" "inventory" {
  content = templatefile("${path.root}/../../templates/inventory-vault-cluster.yaml.tftpl", {

    # Use the variable passed from the layer
    ansible_ssh_user     = var.vm_credentials.username,
    vault_nodes          = var.vault_nodes,
    vault_allowed_subnet = var.ansible_config.extra_vars.vault_allowed_subnet
    haproxy_node         = var.haproxy_node
  })
  filename = "${var.ansible_config.root_path}/inventory-vault-cluster.yaml"
}

resource "null_resource" "provision_cluster" {

  depends_on = [local_file.inventory]

  triggers = {
    vm_status         = jsonencode(var.status_trigger)
    inventory_content = local_file.inventory.content
  }

  provisioner "local-exec" {

    working_dir = abspath("${path.root}/../../../")

    /*
     * To avoid "(output suppressed due to sensitive value in config)" shown in terminal
     * Use `nonsensitive()` function to decrypt the playbook log.
     * `rm-rf` is to ensure the destination directory for fetched files exists and is clean
    */
    command = <<-EOT
      set -e
      ansible-playbook \
        -i ${local_file.inventory.filename} \
        --private-key ${nonsensitive(var.vm_credentials.ssh_private_key_path)} \
        --ssh-common-args='-F ${var.ansible_config.ssh_config_path}' \
        --extra-vars "ansible_ssh_user=${nonsensitive(var.vm_credentials.username)}" \
        --extra-vars "vault_keepalived_auth_pass=${nonsensitive(var.infra_credentials.auth_pass)}" \
        --extra-vars "vault_haproxy_stats_pass=${nonsensitive(var.infra_credentials.stats_pass)}" \
        -v \
        ${var.ansible_config.root_path}/playbooks/10-provision-vault.yaml
    EOT

    interpreter = ["/bin/bash", "-c"]
  }
}
