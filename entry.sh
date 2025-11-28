#!/bin/bash

set -e -u

###
# SCRIPT INITIALIZATION AND MODULE LOADING
###

# Define base directory and load configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_LIB_DIR="${SCRIPT_DIR}/scripts"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly PACKER_DIR="${SCRIPT_DIR}/packer"
readonly USER_HOME_DIR="${HOME}"
readonly ANSIBLE_DIR="${SCRIPT_DIR}/ansible"

source "${SCRIPTS_LIB_DIR}/utils_environment.sh"

###
# MAIN ENVIRONMENT BOOTSTRAP LOGIC
###
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

### Set correct permissions since 

if [[ "${ENVIRONMENT_STRATEGY}" == "native" ]]; then
  echo "INFO: Switching to 'native' mode. Running pre-emptive permission check..."
  check_and_fix_permissions
  # Exit if the fix failed, preventing a switch to a broken state.
  if [ $? -ne 0 ]; then
    echo "FATAL: Permission fix failed. Aborting strategy switch." >&2
    exit 1
  fi
fi

# Set Terraform directory based on the selected provider

read -r -a ALL_PACKER_BASES <<< "$ALL_PACKER_BASES"
read -r -a ALL_TERRAFORM_LAYERS <<< "$ALL_TERRAFORM_LAYERS"

# Main menu
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
options+=("[ONCE-ONLY] Set up CA Certs for TLS")
options+=("[ONCE-ONLY] Initialize Vault")
options+=("[ONCE-ONLY] Generate SSH Key")
options+=("[ONCE-ONLY] Setup KVM / QEMU for Native")
options+=("[ONCE-ONLY] Setup Core IaC Tools for Native")
options+=("[ONCE-ONLY] Verify IaC Environment for Native")
options+=("Unseal Vault")
options+=("Switch Environment Strategy")
options+=("Purge All Libvirt Resources")
options+=("Purge All Packer and Terraform Resources")
options+=("Build Packer Base Image")
options+=("Provision Terraform Layer")
options+=("[DEV] Rebuild Layer via Ansible Command")
options+=("Verify SSH")
options+=("Quit")
# options+=("Rebuild Terraform Layer 10: KVM Provision Only")
# options+=("Rebuild Terraform Layer 10: Ansible Bootstrapper Only")

select opt in "${options[@]}"; do
  # Record start time
  readonly START_TIME=$(date +%s)

  case $opt in
    "[ONCE-ONLY] Set up CA Certs for TLS")
      echo "# INFO: Follow the instruction below"
      vault_tls_generator
      break
      ;;
    "[ONCE-ONLY] Initialize Vault")
      echo "# WARNING: This is a destructive operation for existing data."
      vault_cluster_bootstrapper
      break
      ;;
    "[ONCE-ONLY] Generate SSH Key")
      echo "# Generate SSH Key for this project..."
      ssh_key_generator_handler
      echo "# SSH Key successfully generated in the path '~/.ssh'."
      break
      ;;
    "[ONCE-ONLY] Setup KVM / QEMU for Native")
      echo "# Executing Setup KVM / QEMU workflow..."
      if libvirt_install_handler; then
        libvirt_environment_setup_handler
      fi
      echo "# Setup KVM / QEMU workflow completed."
      break
      ;;
    "[ONCE-ONLY] Setup Core IaC Tools for Native")
      echo "# Executing Setup Core IaC Tools workflow..."
      if iac_tools_install_prompter; then
        iac_tools_installation_handler
      fi
      echo "# Setup Core IaC Tools workflow completed."
      break
      ;;
    "[ONCE-ONLY] Verify IaC Environment for Native")
      env_native_verifier
      break
      ;;
    "Unseal Vault")
      echo "# Executing standard Vault startup workflow..."
      vault_seal_handler
      break
      ;;
    "Switch Environment Strategy")
      strategy_switch_handler
      ;;
    "Purge All Libvirt Resources")
      if ! manual_confirmation_prompter "Libvirt resources (VMs, Networks, Storage Pools)"; then break; fi
      libvirt_service_manager
      libvirt_resource_purger "all"
      break
      ;;
    "Purge All Packer and Terraform Resources")
      if ! manual_confirmation_prompter "Packer images and Terraform states"; then break; fi
      echo "# Executing Reset All workflow..."
      packer_artifact_cleaner "all"
      terraform_artifact_cleaner "all"
      execution_time_reporter
      echo "# Reset All workflow completed."
      break
      ;;
    "Build Packer Base Image")
      echo "# Entering Packer build selection menu..."
      libvirt_service_manager
      packer_menu_handler
      break
      ;;
    "Provision Terraform Layer")
      echo "# Entering Terraform layer management menu..."
      libvirt_service_manager
      terraform_layer_selector
      break
      ;;
    "[DEV] Rebuild Layer via Ansible Command")
      echo "# Executing [DEV] Rebuild via direct Ansible command..."
      if ! ssh_key_verifier; then break; fi
      libvirt_service_manager
      ansible_menu_handler
      execution_time_reporter
      echo "# [DEV] Rebuild via direct Ansible command completed."
      break
      ;;
    "Verify SSH")
      echo "# Executing Verify SSH workflow..."
      if ! ssh_key_verifier; then break; fi
      ssh_verification_handler
      echo "# Verify SSH workflow completed."
      break
      ;;
    "Quit")
      echo "# Exiting script."
      break
      ;;
    *) echo "# Invalid option $REPLY";;
  esac
done
