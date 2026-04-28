
terraform {
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.8.0"
    }
  }
}

locals {
  global_vars   = var.inventory_data.all.vars
  playbook_path = [
    abspath("${path.module}/../../../../ansible/playbooks/10-provision-core-services.yaml"),
    abspath("${path.module}/../../../../ansible/playbooks/20-provision-data-services.yaml"),
    abspath("${path.module}/../../../../ansible/playbooks/30-provision-kubeadm.yaml"),
    abspath("${path.module}/../../../../ansible/playbooks/30-provision-microk8s.yaml"),
  ]
}

resource "local_file" "inventory" {
  content = format(
    "%s\n\n# Terraform Status Trigger: %s",
    yamlencode(var.inventory_data),
    jsonencode(var.status_trigger)
  )
  filename        = "${var.ansible_config.root_path}/${var.ansible_config.inventory_file}"
  file_permission = "0644"

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.ansible_playbook_run.run_playbook]
    }
  }
}

data "local_file" "base_ansible_cfg" {
  filename = "${var.ansible_config.root_path}/../ansible.cfg"
}

resource "local_file" "ansible_cfg" {
  content = replace(
    replace(
      data.local_file.base_ansible_cfg.content,
      "roles_path = ansible/roles",
      "roles_path = ${var.ansible_config.root_path}/roles"
    ),
    "inventory = ansible/inventory.yaml",
    "inventory = ${local_file.inventory.filename}"
  )
  filename = "${path.cwd}/ansible.cfg"
}


action "ansible_playbook_run" "run_playbook" {
  config {
    playbooks = local.playbook_path

    extra_vars = merge(
      local.global_vars,
      var.extra_vars
    )

    ansible_playbook_binary = "ansible-playbook"
  }
}
