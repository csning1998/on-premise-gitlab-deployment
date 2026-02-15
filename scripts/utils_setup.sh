#!/bin/bash

# This script contains functions related to the setup of the
# Infrastructure as Code (IaC) environment.

# Function: Verify if Libvirt/KVM tools are installed (non-interactive).
libvirt_tools_verifier() {
  log_print "STEP" "Verifying Libvirt/KVM environment..."
  local all_installed=true
  local tools_to_check=(
    "qemu-system-x86_64:QEMU/KVM"
    "virsh:Libvirt Client (virsh)"
  )
  for tool_entry in "${tools_to_check[@]}"; do
    local cmd="${tool_entry%%:*}"
    local name="${tool_entry#*:}"
    if command -v "$cmd" >/dev/null 2>&1; then
      log_print "INFO" "${name}: Installed"
    else
      log_print "WARN" "${name}: Missing"
      all_installed=false
    fi
  done
  if $all_installed; then return 0; else return 1; fi
}

# Function: Verify if Core IaC tools are installed (non-interactive).
iac_tools_verifier() {
  log_print "STEP" "Verifying Core IaC Tools (HashiCorp/Ansible)..."
  local all_installed=true
  local tools_to_check=(
    "packer:HashiCorp Packer"
    "terraform:HashiCorp Terraform"
    "vault:HashiCorp Vault"
    "ansible:Red Hat Ansible"
  )
  for tool_entry in "${tools_to_check[@]}"; do
    local cmd="${tool_entry%%:*}"
    local name="${tool_entry#*:}"
    if command -v "$cmd" >/dev/null 2>&1; then
      log_print "INFO" "${name}: Installed"
    else
      log_print "WARN" "${name}: Missing"
      all_installed=false
    fi
  done
  if $all_installed; then return 0; else return 1; fi
}


# Function: Verify all native environment tools (non-interactive).
env_native_verifier() {
  log_print "STEP" "Verifying full native IaC environment..."
  local libvirt_ok=true
  local iac_ok=true
  libvirt_tools_verifier || libvirt_ok=false
  iac_tools_verifier || iac_ok=false
  log_divider
  if $libvirt_ok && $iac_ok; then
    log_print "OK" "Verification successful: All required tools are installed."
    return 0
  else
    log_print "ERROR" "Verification failed: Some required tools are missing."
    return 1
  fi
}

# Function: Prompt user to install Libvirt tools (interactive).
libvirt_install_handler() {
  if libvirt_tools_verifier; then
    log_print "INPUT" "Libvirt/KVM is already installed. Reinstall? (y/n): "
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then return 1; fi
  else
    log_print "INPUT" "Libvirt/KVM is not installed. Proceed with installation? (y/n): "
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then return 1; fi
  fi
  return 0
}

# Function: Prompt user to install Core IaC tools (interactive).
iac_tools_install_prompter() {
  if iac_tools_verifier; then
    log_print "INPUT" "Core IaC tools are already installed. Reinstall? (y/n): "
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then return 1; fi
  else
    log_print "INPUT" "Some Core IaC tools are missing. Proceed with installation? (y/n): "
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then return 1; fi
  fi
  return 0
}

# Function: Setup KVM, QEMU, and Libvirt environment
libvirt_environment_setup_handler() {
  log_print "STEP" "Setting up Libvirt/KVM environment for OS Family: ${HOST_OS_FAMILY^^}..."

  if [[ "${HOST_OS_FAMILY}" == "rhel" ]]; then
    # --- RHEL / Fedora Libvirt Setup ---
    log_print "TASK" "Installing KVM/QEMU packages..."
    sudo dnf install -y qemu-kvm libvirt-client virt-install
    
    log_print "TASK" "Enabling and starting libvirt service..."
    sudo systemctl enable --now libvirtd
    
    log_print "TASK" "Adding current user to 'libvirt' group..."
    sudo usermod -aG libvirt "$(whoami)"
    
    # Create the required symlink for Packer
    if [ -f /usr/libexec/qemu-kvm ] && [ ! -f /usr/bin/qemu-system-x86_64 ]; then
      log_print "TASK" "Creating symlink for qemu-system-x86_64..."
      sudo ln -s /usr/libexec/qemu-kvm /usr/bin/qemu-system-x86_64
    fi
		echo
    log_print "WARN" "############################################################################"
    log_print "WARN" "### ACTION REQUIRED: Please log out and log back in for group changes to ###"
    log_print "WARN" "### take effect before running Packer or Terraform for KVM.              ###"
    log_print "WARN" "############################################################################"
    echo

  elif [[ "${HOST_OS_FAMILY}" == "debian" ]]; then
    # --- Debian / Ubuntu Libvirt Setup ---
    log_print "TASK" "Installing KVM/QEMU packages for Debian/Ubuntu..."
    sudo apt-get update
    sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
    
    log_print "TASK" "Enabling and starting libvirt service..."
    sudo systemctl enable --now libvirtd
    
    log_print "TASK" "Adding current user to 'libvirt' and 'kvm' groups..."
    sudo adduser "$(whoami)" libvirt
    sudo adduser "$(whoami)" kvm
    
    echo
    log_print "WARN" "################################################################################"
    log_print "WARN" "###                      IMPORTANT: KVM Post-Install Setup                   ###"
    log_print "WARN" "################################################################################"
    echo
    log_print "INFO" "To ensure Packer and Terraform can operate correctly, several system-level"
    log_print "INFO" "configurations are required for KVM on Debian-based systems."
    echo
    log_print "INPUT" "Do you want to proceed with these automated changes? (y/n): "
    read -r -n 1
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
      log_print "TASK" "Proceeding with KVM configuration fixes..."

      # Stop all services first to ensure a clean state for configuration
      log_print "TASK" "Stopping services for reconfiguration..."
      sudo systemctl stop libvirtd.service >/dev/null 2>&1 || true
      sudo systemctl stop libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket >/dev/null 2>&1 || true

      # Apply all file-based configurations while services are stopped
      log_print "TASK" "Applying file-based configurations..."
      sudo systemctl disable libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket >/dev/null 2>&1 || true
      
      sudo sed -i 's/#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/' /etc/libvirt/libvirtd.conf
      sudo sed -i 's/#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/' /etc/libvirt/libvirtd.conf

      sudo sed -i "s/^#*user = .*/user = \"$(whoami)\"/" /etc/libvirt/qemu.conf
      sudo sed -i "s/^#*group = .*/group = \"$(whoami)\"/" /etc/libvirt/qemu.conf
      if sudo grep -q "^#*security_driver" /etc/libvirt/qemu.conf; then
        sudo sed -i 's/^#*security_driver = .*/security_driver = "none"/g' /etc/libvirt/qemu.conf
      else
        echo 'security_driver = "none"' | sudo tee -a /etc/libvirt/qemu.conf >/dev/null
      fi

      sudo mkdir -p /etc/qemu
      echo 'allow virbr0' | sudo tee /etc/qemu/bridge.conf >/dev/null

      if [ -f /usr/lib/qemu/qemu-bridge-helper ]; then
        sudo chmod u+s /usr/lib/qemu/qemu-bridge-helper
      fi

      log_print "TASK" "Enabling and restarting libvirtd service..."
      sudo systemctl enable libvirtd.service >/dev/null 2>&1
      sudo systemctl restart libvirtd.service
      sleep 2 
      
      log_print "TASK" "(4/4) Final service restart to ensure all settings are loaded..."
      sudo systemctl restart libvirtd.service
      echo
      log_print "OK" "KVM fixes applied successfully."
      log_print "WARN" "################################################################################"
      log_print "WARN" "###    ACTION REQUIRED: Please REBOOT your system now for all changes      ###"
      log_print "WARN" "###    (especially user groups and libvirt settings) to take full effect.  ###"
      log_print "WARN" "################################################################################"
    else
      log_print "WARN" "Skipping automatic KVM configuration fixes. Packer and Terraform may fail."
    fi
    log_divider
  fi
  log_print "OK" "Libvirt/KVM environment setup completed."
}

# Function: Install OS-specific base dependencies
os_dependency_install_handler() {
  log_print "TASK" "Installing OS-specific base packages for ${HOST_OS_FAMILY^^}..."

  if [[ "${HOST_OS_FAMILY}" == "rhel" ]]; then
    sudo dnf install -y jq python3-pip wget curl whois gnupg openssh-clients unzip
  elif [[ "${HOST_OS_FAMILY}" == "debian" ]]; then
    sudo apt-get update
    sudo apt-get install -y jq python3-pip wget curl whois gnupg openssh-client unzip
  else
    log_print "FATAL" "Unsupported OS family for native installation: ${HOST_OS_FAMILY}"
    exit 1
  fi
}

# Function: Install Ansible using pip
ansible_core_install_handler() {
  log_print "TASK" "Installing Ansible Core using pip..."
  sudo pip3 install ansible-core
	sudo /usr/bin/python3 -m pip install hvac

  log_print "TASK" "Installing Ansible Galaxy collections..."
  ansible-galaxy collection install ansible.posix community.general community.docker community.kubernetes community.crypto community.hashi_vault
}

# Function: Install HashiCorp tools using the universal binary method
hashicorp_tool_install_handler() {
  log_print "INFO" "Installing HashiCorp Toolkits (Terraform, Packer, Vault)..."
  local tools="terraform packer vault"

  for tool in ${tools}; do
    log_print "TASK" "Installing ${tool}..."
    local latest_url
    local extract_dir
    extract_dir=$(mktemp -d)

    trap 'rm -rf -- "$extract_dir"' EXIT # Ensure this dir is cleaned up even if the script fails

    latest_url=$(curl -sL "https://releases.hashicorp.com/${tool}/index.json" | jq -r '.versions[].builds[] | select(.arch=="amd64" and .os=="linux") | .url' | sort -V | tail -n 1)

    if [[ -z "${latest_url}" ]]; then
        log_print "ERROR" "Could not find download URL for ${tool}. Skipping."
        rm -rf -- "$extract_dir"
        trap - EXIT
        continue
    fi

    log_print "TASK" "Downloading to a temporary location..."
    curl -Lo "${extract_dir}/${tool}.zip" "${latest_url}"

    log_print "TASK" "Extracting in an isolated directory: ${extract_dir}"
    unzip -o "${extract_dir}/${tool}.zip" -d "${extract_dir}"
    
    log_print "TASK" "Installing to /usr/local/bin/${tool}"
    sudo mv "${extract_dir}/${tool}" /usr/local/bin/
    sudo chmod +x "/usr/local/bin/${tool}"

    rm -rf -- "$extract_dir"
    trap - EXIT
  done
}

# Function: Main Orchestration of installation ---
iac_tools_installation_handler() {
  log_print "STEP" "Setting up core IaC tools..."
  
  # Ensure core commands needed by the script itself are present
  command -v curl >/dev/null 2>&1 || { log_print "FATAL" "curl is not installed. Please install it first."; exit 1; }
  command -v jq >/dev/null 2>&1 || { log_print "FATAL" "jq is not installed. Please install it first."; exit 1; }

  os_dependency_install_handler
  ansible_core_install_handler
  hashicorp_tool_install_handler

  log_print "INFO" "Verifying installed tools..."
  iac_tools_verifier

  log_print "OK" "Core IaC tools setup and verification completed."
}
