
# Common Ansible provisioner shared between all Packer layers.
# This file is symlinked into specific layer directories.

build {
  # This block will be merged with other build blocks sharing the same source.
  sources = ["source.qemu.ubuntu"]

  provisioner "ansible" {
    playbook_file       = "../../ansible/playbooks/00-provision-base-image.yaml"
    inventory_directory = "../../ansible/"
    user                = local.ssh_username
    groups              = [var.build_name]

    ansible_env_vars = [
      "ANSIBLE_CONFIG=../../ansible.cfg"
    ]
    extra_arguments = [
      "--extra-vars", "expected_hostname=${local.final_hostname}",
      "--extra-vars", "public_key_file=${vault("secret/data/on-premise-gitlab-deployment/variables", "ssh_public_key_path")}",
      "--extra-vars", "ssh_user=${local.ssh_username}",
      "--extra-vars", "ansible_ssh_transfer_method=piped",
      "-v",
    ]
  }
}
