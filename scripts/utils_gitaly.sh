#!/bin/bash

gitaly_revert_to_standalone_trigger() {
  log_print "STEP" "[Gitaly] Triggering safety pre-check before reverting to standalone..."

  local inventory_file="${ANSIBLE_DIR}/inventory-core-gitlab-praefect.yaml"
  local playbook_file="${ANSIBLE_DIR}/playbooks/90-operation-playbook.yaml"

  if [[ ! -f "$inventory_file" ]]; then
    log_print "ERROR" "Inventory file not found at: $inventory_file"
    return 1
  fi

  if [[ ! -f "$playbook_file" ]]; then
    log_print "ERROR" "Playbook file not found at: $playbook_file"
    return 1
  fi

  log_divider "!"
  log_print "WARN" "This pre-check must complete BEFORE removing Praefect nodes from Terraform."
  log_print "WARN" "If gitaly-0 has missing replicas, proceeding will cause data loss."
  log_divider "!"
  log_print "INPUT" "Type 'Y' or 'y' to confirm execution: "
  read -r confirmation
  if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
    log_print "INFO" "Operation aborted by user."
    return 1
  fi

  if ansible-playbook \
    -i "$inventory_file" \
    "$playbook_file" \
    --tags gitaly-revert-standalone; then
    log_print "OK" "[Gitaly] Pre-check passed. Gitaly-0 has all repositories."
    log_print "INFO" "Safe to proceed:"
    log_print "INFO" "  1. Remove Praefect nodes from terraform.tfvars"
    log_print "INFO" "  2. Run: terraform apply"
  else
    log_print "ERROR" "[Gitaly] Pre-check FAILED. Do NOT proceed with Terraform revert."
    return 1
  fi
}
