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
