#!/bin/bash

set -e -u

# Define base directory and load configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_LIB_DIR="${SCRIPT_DIR}/scripts"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly PACKER_DIR="${SCRIPT_DIR}/packer"
readonly ANSIBLE_DIR="${SCRIPT_DIR}/ansible"

# Load environment variables
source "${SCRIPTS_LIB_DIR}/utils_environment.sh"

# MAIN ENVIRONMENT BOOTSTRAP LOGIC
host_os_detail_handler
cpu_virt_support_checker
env_file_bootstrapper
iac_layer_discoverer

# Source the .env file to export its variables to any sub-processes
set -o allexport
source .env
set +o allexport

# initialize_environment
for lib in "${SCRIPTS_LIB_DIR}"/*.sh; do
  if [[ "$lib" != *"/utils_environment.sh" ]]; then
    source "$lib"
  fi
done

# Set correct permissions since 
if [[ "${ENVIRONMENT_STRATEGY}" == "native" ]]; then
  check_and_fix_permissions || { echo "FATAL: Permission fix failed."; exit 1; }
fi

# Set Terraform directory based on the selected provider
read -r -a ALL_PACKER_BASES <<< "$ALL_PACKER_BASES"
read -r -a ALL_TERRAFORM_LAYERS <<< "$ALL_TERRAFORM_LAYERS"

#  Main Menu
echo
echo "======= IaC-Driven Virtualization Management ======="
echo
echo "Environment: ${ENVIRONMENT_STRATEGY^^}"
if [[ "${ENVIRONMENT_STRATEGY}" == "container" ]]; then
  echo "Engine: PODMAN"
fi
vault_status_reporter
echo

PS3=">>> Please select an action: "
options=()

# [Dev Vault - Bootstrap Unit]
options+=("[DEV] Set up TLS for Dev Vault (Local)")
options+=("[DEV] Initialize Dev Vault (Local)")
options+=("[DEV] Unseal Dev Vault (Local)")

# [Prod Vault - Service Provider]
options+=("[PROD] Unseal Production Vault (via Ansible)")

# [Infrastructure]
options+=("Generate SSH Key")
options+=("Setup KVM / QEMU for Native")
options+=("Setup Core IaC Tools")
options+=("Verify IaC Environment")

# [Operations]
options+=("Build Packer Base Image")
options+=("Provision Terraform Layer")
options+=("Rebuild Layer via Ansible")
options+=("Verify SSH")
options+=("Switch Environment Strategy")

# [Reset]
options+=("Purge All Libvirt Resources")
options+=("Purge All Packer and Terraform Resources")
options+=("Quit")

select opt in "${options[@]}"; do
  readonly START_TIME=$(date +%s)

  case $opt in
    # --- Dev Vault ---
    "[DEV] Set up TLS for Dev Vault (Local)")
      vault_dev_tls_generator
      break
      ;;
    "[DEV] Initialize Dev Vault (Local)")
      vault_dev_init_handler
      break
      ;;
    "[DEV] Unseal Dev Vault (Local)")
      vault_dev_seal_handler
      break
      ;;
    
    # --- Prod Vault ---
    "[PROD] Unseal Production Vault (via Ansible)")
      vault_prod_unseal_trigger
      break
      ;;

    # --- Infrastructure ---
    "Generate SSH Key")
      echo "# Generate SSH Key for this project..."
      ssh_key_generator_handler
      echo "# SSH Key successfully generated."
      break
      ;;
    "Setup KVM / QEMU for Native")
      libvirt_install_handler && libvirt_environment_setup_handler
      break
      ;;
    "Setup Core IaC Tools")
      if iac_tools_install_prompter; then iac_tools_installation_handler; fi
      break
      ;;
    "Verify IaC Environment")
      env_native_verifier
      break
      ;;

    # --- Operations ---
    "Build Packer Base Image")
      libvirt_service_manager
      packer_menu_handler
      break
      ;;
    "Provision Terraform Layer")
      libvirt_service_manager
      terraform_layer_selector
      break
      ;;
    "Rebuild Layer via Ansible")
      if ssh_key_verifier; then
        libvirt_service_manager
        ansible_menu_handler
        execution_time_reporter
      fi
      break
      ;;
    "Verify SSH")
      if ssh_key_verifier; then ssh_verification_handler; fi
      break
      ;;
    "Switch Environment Strategy")
      strategy_switch_handler
      ;;

    # --- Reset ---
    "Purge All Libvirt Resources")
      if manual_confirmation_prompter "Libvirt resources"; then
        libvirt_service_manager
        libvirt_resource_purger "all"
      fi
      break
      ;;
    "Purge All Packer and Terraform Resources")
      if manual_confirmation_prompter "Packer images/Terraform states"; then
        packer_artifact_cleaner "all"
        terraform_artifact_cleaner "all"
        execution_time_reporter
      fi
      break
      ;;
    "Quit")
      echo "# Exiting script."
      break
      ;;
    *) echo "# Invalid option $REPLY";;
  esac
done
