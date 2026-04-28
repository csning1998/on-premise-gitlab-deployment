
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
  # Parse the existing inventory content to drive the provider resources
  raw_inv = yamldecode(var.inventory_content)

  # Flatten all hosts from all groups in the inventory
  # This handles the complex group structure defined in the templates
  inv_hosts = merge([
    for group_name, group_data in try(local.raw_inv.all.children, {}) : {
      for host_name, host_data in (try(group_data.hosts, null) != null ? group_data.hosts : {}) :
      "${group_name}_${host_name}" => {
        name         = host_name
        ansible_host = try(host_data.ansible_host, try(host_data.advertise_ip, ""))
        groups       = [group_name, "all_nodes"]
      }
      if host_data != null
    }
  ]...)

  # Extract group variables
  inv_groups = local.raw_inv.all.children

  # Extract global variables from 'all' group and ensure they are strings for extra_vars
  # If it's a complex type, we add a suffix to allow the playbook to decode it without priority conflict
  global_vars = {
    for k, v in lookup(local.raw_inv.all, "vars", {}) : (can(tostring(v)) ? k : "${k}_json_raw") => (
      can(tostring(v)) ? tostring(v) : jsonencode(v)
    )
  }
}

resource "local_file" "inventory" {
  content         = var.inventory_content
  filename        = "${var.ansible_config.root_path}/${var.ansible_config.inventory_file}"
  file_permission = "0644"
}

data "local_file" "base_ansible_cfg" {
  filename = "${var.ansible_config.root_path}/../ansible.cfg"
}

resource "local_file" "ansible_cfg" {
  content = replace(
    data.local_file.base_ansible_cfg.content,
    "roles_path = ansible/roles",
    "roles_path = ${var.ansible_config.root_path}/roles"
  )
  filename = "${path.cwd}/ansible.cfg"
}

resource "ansible_group" "groups" {
  for_each = { for k, v in local.inv_groups : k => v if k != "all" }
  name     = each.key
}

resource "ansible_host" "nodes" {
  for_each = local.inv_hosts
  name     = each.value.name
  groups   = each.value.groups
  variables = {
    ansible_host                 = each.value.ansible_host
    ansible_user                 = nonsensitive(var.credentials_vm.username)
    ansible_ssh_private_key_file = abspath(var.credentials_vm.ssh_private_key_path)
    ansible_ssh_common_args      = "-F ${var.ansible_config.ssh_config_path}"
    vm_status_trigger            = jsonencode(var.status_trigger)
  }
}

resource "ansible_playbook" "run_playbook" {
  for_each   = local.inv_hosts
  playbook   = "${var.ansible_config.root_path}/playbooks/poc-redis-single.yaml"
  name       = each.value.name
  extra_vars = merge(
    local.global_vars,
    var.extra_vars,
    {
      advertise_ip = each.value.ansible_host
    }
  )
  verbosity = 4

  depends_on = [local_file.ansible_cfg, ansible_host.nodes, ansible_group.groups]
}

resource "local_file" "ansible_logs" {
  for_each = local.inv_hosts
  content  = ansible_playbook.run_playbook[each.key].ansible_playbook_stdout
  filename = "${path.cwd}/ansible-log-${each.value.name}.log"
}
