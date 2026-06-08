#!/bin/bash

# This script contains functions for managing OpenTofu resources.

# Function: Clean up a specific OpenTofu layer's state files.
# Parameter 1: The short name of the layer (e.g., "10-provision-kubeadm") or "all".
tofu_artifact_cleaner() {
  local target_layer="$1"
  if [ -z "$target_layer" ]; then
    log_print "FATAL" "No Terraform layer specified for tofu_artifact_cleaner function."
    log_print "INFO" "Available layers: ${ALL_TERRAFORM_LAYERS[*]}"
    return 1
  fi

  local layers_to_clean=()
  if [[ "$target_layer" == "all" ]]; then
    log_print "STEP" "Preparing to clean all Terraform layers..."
    # Convert space-separated string from .env into an array
    read -r -a layers_to_clean <<< "${ALL_TERRAFORM_LAYERS}"
  else
    layers_to_clean=("$target_layer")
  fi

  for layer_name in "${layers_to_clean[@]}"; do
    local layer_dir="${TERRAFORM_DIR}/layers/${layer_name}"

    if [[ ! -d "$layer_dir" ]]; then
      log_print "WARN" "Terraform layer directory not found, skipping: ${layer_dir}"
      continue
    fi

    log_print "STEP" "Cleaning Terraform artifacts..."
    # State files are now managed by GitLab.com HTTP backend; local deletion disabled
    # rm -rf "${layer_dir}/terraform.tfstate" \
    #   "${layer_dir}"/terraform.tfstate*.backup
    log_print "INFO" "Terraform artifact cleanup is completed."
    log_divider
  done
}
