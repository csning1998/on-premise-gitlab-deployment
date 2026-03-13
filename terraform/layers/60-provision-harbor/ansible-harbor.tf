
resource "ansible_host" "harbor_trust" {
  name   = "harbor-microk8s-node-00"
  groups = ["harbor_nodes"]

  variables = {
    ansible_host                 = data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_ip_list[0]
    ansible_user                 = local.vm_username
    ansible_ssh_private_key_file = local.private_key_path
    ansible_python_interpreter   = "/usr/bin/python3"
    ansible_ssh_common_args      = "-o StrictHostKeyChecking=no"
  }
}

resource "ansible_playbook" "harbor_trust" {

  depends_on = [module.harbor_core, ansible_host.harbor_trust]

  playbook   = "${path.module}/ansible/harbor_trust.yaml"
  name       = ansible_host.harbor_trust.name
  groups     = ansible_host.harbor_trust.groups
  replayable = true

  extra_vars = {
    ansible_host                 = ansible_host.harbor_trust.variables["ansible_host"]
    ansible_user                 = ansible_host.harbor_trust.variables["ansible_user"]
    ansible_ssh_private_key_file = ansible_host.harbor_trust.variables["ansible_ssh_private_key_file"]
    ansible_ssh_common_args      = ansible_host.harbor_trust.variables["ansible_ssh_common_args"]
    harbor_domain                = local.harbor_hostname
  }
}
