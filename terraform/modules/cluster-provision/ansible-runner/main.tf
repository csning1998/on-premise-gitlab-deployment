
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

data "local_file" "base_ansible_cfg" {
  filename = "${var.ansible_config.root_path}/../ansible.cfg"
}

locals {
  playbook_path = [
    abspath("${path.module}/../../../../ansible/playbooks/10-playbook-shared.yaml"),
    # abspath("${path.module}/../../../../ansible/playbooks/30-playbook-infra-statesful-sets.yaml"),
    # abspath("${path.module}/../../../../ansible/playbooks/30-playbook-frontend.yaml"),
  ]
}

resource "local_file" "inventory" {
  content = format(
    "---\n%s\n# Terraform Status Trigger: %s", # Render YAML opening with terraform status tracking code
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
    playbooks               = local.playbook_path
    extra_vars              = var.extra_vars
    verbosity               = 2
    ansible_playbook_binary = "ansible-playbook"
  }
}
