
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
  # 1. Identify all unique groups (excluding 'all')
  groups = var.inventory_data.all.children

  # 2. Extract every host occurrence to find which groups each host belongs to
  all_host_occurrences = flatten([
    for g_name, g_data in local.groups : [
      for h_name, h_data in g_data.hosts : {
        group = g_name
        host  = h_name
        vars  = h_data != null ? h_data : {}
      }
    ] if g_data.hosts != null
  ])

  # 3. Group by host name to merge variables and distinct groups
  hosts_grouped = {
    for occ in local.all_host_occurrences : occ.host => occ...
  }

  # 4. Final host definition
  final_hosts = {
    for h_name, occs in local.hosts_grouped : h_name => {
      name   = h_name
      groups = distinct(concat([for o in occs : o.group], ["all_nodes"]))
      vars   = merge([for o in occs : o.vars]...)
    }
  }

  global_vars = var.inventory_data.all.vars
  # playbook_path = "${var.ansible_config.root_path}/${var.ansible_config.playbook_file}"
  playbook_path = "/home/csning1998/GitHub/on-premise-gitlab-deployment/ansible/playbooks/20-provision-data-services.yaml"
}

resource "ansible_group" "groups" {
  for_each = local.groups
  name     = each.key
}

resource "ansible_host" "nodes" {
  for_each = local.final_hosts
  name     = each.key
  groups   = each.value.groups

  variables = merge(
    each.value.vars,
    {
      ansible_host                 = each.value.vars.advertise_ip
      advertise_ip                 = each.value.vars.advertise_ip
      ansible_user                 = nonsensitive(var.credentials_vm.username)
      ansible_ssh_private_key_file = pathexpand(var.credentials_vm.ssh_private_key_path)
      ansible_ssh_common_args      = "-F ${var.ansible_config.ssh_config_path}"
      vm_status_trigger            = jsonencode(var.status_trigger)
    }
  )
}

resource "local_file" "inventory" {
  content         = yamlencode(var.inventory_data)
  filename        = "${var.ansible_config.root_path}/${var.ansible_config.inventory_file}"
  file_permission = "0644"
  depends_on = [ansible_host.nodes]

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
    playbooks = [local.playbook_path]

    extra_vars = merge(
      local.global_vars,
      var.extra_vars
    )

    ansible_playbook_binary = "ansible-playbook"
  }
}

# Commented out logs as Action mode doesn't provide stdout in this version.
/*
resource "local_file" "ansible_logs" {
  content  = ansible_playbook_run.run_playbook.ansible_playbook_stdout
  filename = "${path.cwd}/ansible-deployment.log"
}
*/
