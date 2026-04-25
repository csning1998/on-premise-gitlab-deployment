#!/bin/bash

# Function: Verify all native environment tools (non-interactive).
env_native_verifier() {
  log_print "STEP" "Verifying full native IaC environment..."

  local all_ok=true

  # Category: Libvirt/KVM
  local libvirt_tools=(
    "qemu-system-x86_64:QEMU/KVM"
    "virsh:Libvirt Client (virsh)"
  )

  # Category: Core IaC Tools
  local iac_tools=(
    "packer:HashiCorp Packer"
    "terraform:HashiCorp Terraform"
    "tofu:OpenTofu"
    "vault:HashiCorp Vault"
    "ansible:Red Hat Ansible"
  )

  # Inner function to process categories
  check_tool_group() {
    local group_name="$1"
    shift
    local tools=("$@")
    local group_ok=true

    log_print "STEP" "Checking ${group_name}..."
    for tool_entry in "${tools[@]}"; do
      local cmd="${tool_entry%%:*}"
      local name="${tool_entry#*:}"

      if command -v "$cmd" >/dev/null 2>&1; then
        log_print "INFO" "${name}: Installed"
      else
        log_print "WARN" "${name}: Missing"
        group_ok=false
        all_ok=false
      fi
    done
    return $([[ "$group_ok" == "true" ]])
  }

  check_tool_group "Libvirt/KVM Environment" "${libvirt_tools[@]}"
  check_tool_group "Core IaC Tools (HashiCorp/OpenTofu/Ansible)" "${iac_tools[@]}"

  log_divider
  if $all_ok; then
    log_print "OK" "Verification successful: All required tools are installed."
    return 0
  else
    log_print "ERROR" "Verification failed: Some required tools are missing."
    return 1
  fi
}
