terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

resource "local_file" "inventory" {
  content         = var.inventory_content
  filename        = "${var.ansible_config.root_path}/${var.ansible_config.inventory_file}"
  file_permission = "0644"
}

resource "null_resource" "run_playbook" {
  triggers = {
    vm_status         = jsonencode(var.status_trigger)
    inventory_content = var.inventory_content
    playbook          = var.ansible_config.playbook_file
    extra_vars        = jsonencode(var.extra_vars)
  }

  depends_on = [local_file.inventory]

  provisioner "local-exec" {
    working_dir = abspath("${path.module}/../../../")

    command = <<-EOT
      set -e
%{for cmd in var.pre_run_commands~}
      echo ">>> Executing pre-run command: ${cmd}"
      ${cmd}
%{endfor~}

      echo ">>> Running Ansible Playbook: ${var.ansible_config.playbook_file}"
      ansible-playbook \
        -i ${local_file.inventory.filename} \
        --private-key ${nonsensitive(var.vm_credentials.ssh_private_key_path)} \
        --ssh-common-args='-F ${var.ansible_config.ssh_config_path}' \
        --extra-vars "ansible_ssh_user=${nonsensitive(var.vm_credentials.username)}" \
%{for k, v in var.extra_vars~}
        --extra-vars "${k}=${nonsensitive(v)}" \
%{endfor~}
        -v \
        ${var.ansible_config.root_path}/${var.ansible_config.playbook_file}
    EOT

    interpreter = ["/bin/bash", "-c"]
  }
}
