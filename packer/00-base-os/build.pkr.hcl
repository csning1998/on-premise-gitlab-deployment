
# This file defines the build block for the OS Base layer.

packer {
  required_plugins {
    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

build {
  sources = ["source.qemu.ubuntu"]

  # OS Installation & Upgrade Provisioner
  provisioner "shell" {
    execute_command = "echo '${local.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"

    inline = [
      "/usr/bin/cloud-init status --wait",

      "UBUNTU_CODENAME=$(lsb_release -cs)",
      "echo \"Detected Ubuntu Codename: $UBUNTU_CODENAME\"",

      "rm -f /etc/apt/sources.list.d/ubuntu.sources",

      "echo \"deb http://archive.ubuntu.com/ubuntu $${UBUNTU_CODENAME} main restricted universe multiverse\" | tee /etc/apt/sources.list",
      "echo \"deb http://archive.ubuntu.com/ubuntu $${UBUNTU_CODENAME}-updates main restricted universe multiverse\" | tee -a /etc/apt/sources.list",
      "echo \"deb http://archive.ubuntu.com/ubuntu $${UBUNTU_CODENAME}-backports main restricted universe multiverse\" | tee -a /etc/apt/sources.list",
      "echo \"deb http://security.ubuntu.com/ubuntu $${UBUNTU_CODENAME}-security main restricted universe multiverse\" | tee -a /etc/apt/sources.list",

      "apt-get update",
      "apt-get dist-upgrade -y",
      "apt-get autoremove -y",
      "apt-get clean",

      "apt-get install -y openssh-sftp-server",
      "systemctl restart ssh"
    ]
  }

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
