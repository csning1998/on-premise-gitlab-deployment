#!/bin/bash

# This script contains functions for managing Terraform resources.

# Function: Clean up a specific Terraform layer's state files.
# Parameter 1: The short name of the layer (e.g., "10-provision-kubeadm") or "all".
terraform_artifact_cleaner() {
  local target_layer="$1"
  if [ -z "$target_layer" ]; then
    echo "FATAL: No Terraform layer specified for terraform_artifact_cleaner function." >&2
    echo "Available layers: ${ALL_LAYERS[*]}" >&2
    return 1
  fi

  local layers_to_clean=()
  if [[ "$target_layer" == "all" ]]; then
    echo ">>> STEP: Preparing to clean all Terraform layers..."
    layers_to_clean=("${ALL_LAYERS[@]}")
  else
    layers_to_clean=("$target_layer")
  fi

  for layer_name in "${layers_to_clean[@]}"; do
    local layer_dir="${TERRAFORM_DIR}/layers/${layer_name}"

    if [[ ! -d "$layer_dir" ]]; then
      echo "Warning: Terraform layer directory not found, skipping: ${layer_dir}"
      continue
    fi

    # echo ">>> STEP: Cleaning Terraform artifacts for layer [${layer_name}]..."
    # rm -rf "${layer_dir}/.terraform.lock.hcl" \
    #   "${layer_dir}/terraform.tfstate" \
    #   "${layer_dir}/terraform.tfstate.backup"

    # echo "#### Terraform artifact cleanup for [${layer_name}] completed."
    echo "--------------------------------------------------"
  done
}

# Function: Apply a Terraform configuration for a specific layer.
terraform_layer_executor() {
  local layer_name="$1"          # Parameter 1: The short name of the layer.
  local target_resource="${2:-}" # Parameter 2 (Optional): A specific resource target.

  if [ -z "$layer_name" ]; then
    echo "FATAL: No Terraform layer specified for terraform_layer_executor function." >&2
    return 1
  fi

  local layer_dir="${TERRAFORM_DIR}/layers/${layer_name}"
  if [ ! -d "$layer_dir" ]; then
    echo "FATAL: Terraform layer directory not found: ${layer_dir}" >&2
    return 1
  fi

  echo ">>> STEP: Applying Terraform configuration for layer [${layer_name}]..."

  # 1. Basic Shell
  local cmd_init="terraform init -upgrade"
  local cmd_destroy="terraform destroy -auto-approve -var-file=./terraform.tfvars"
  local cmd_apply="terraform apply -auto-approve -var-file=./terraform.tfvars"

  # 2. If Target is specified, add it to Destroy & Apply commands
  if [ -n "$target_resource" ]; then
    echo "#### Targeting resource: ${target_resource}"
    cmd_destroy+=" ${target_resource}"
    cmd_apply+=" ${target_resource}"
  fi

  # 3. Combine commands
  local cmd="${cmd_init} && ${cmd_destroy} && ${cmd_init} && ${cmd_apply}"

  run_command "${cmd}" "${layer_dir}"

  echo "#### Terraform apply for [${layer_name}] complete."
  echo "--------------------------------------------------"
}

# Function: Display a sub-menu to select a Terraform layer for a full rebuild.
terraform_layer_selector() {
  local layer_options=("${ALL_TERRAFORM_LAYERS[@]}" "Back to Main Menu")

  PS3=">>> Select a Terraform layer to REBUILD: "
  select layer in "${layer_options[@]}"; do
    if [[ "$layer" == "Back to Main Menu" ]]; then
      echo "# Returning to main menu..."
      break

    elif [[ " ${ALL_TERRAFORM_LAYERS[*]} " == *"${layer}"* ]]; then
      echo "# Executing Full Rebuild for [${layer}]..."
      if ! ssh_key_verifier; then break; fi
      libvirt_resource_purger "${layer}"
      libvirt_service_manager
      terraform_artifact_cleaner "${layer}"
      
      if [[ "$layer" == "10-vault-core" ]]; then
          echo ">>> [Vault Core] Detected complex layer. Initiating 2-Stage Bootstrap..."
          local tls_dir="${TERRAFORM_DIR}/layers/10-vault-core/tls"
          local token_file="${ANSIBLE_DIR}/fetched/vault/vault_init_output.json"

          mkdir -p "$tls_dir" && touch "$tls_dir/vault-ca.crt"  # 1. Dummy CA
          rm -rf "${ANSIBLE_DIR}/fetched/vault"                 # 2. Dummy Token

					# 3. Since refrash is set to false (below), the state files should be removed manually.
					rm -rf "${TERRAFORM_DIR}"/layers/10-vault-core/terraform.tfstate
					rm -rf "${TERRAFORM_DIR}"/layers/10-vault-core/terraform.tfstate.backup

					# 4. Create the token file with a placeholder value.
          mkdir -p "$(dirname "$token_file")"
          echo '{"root_token": "placeholder-for-bootstrap"}' > "$token_file"

          echo ">>> [Vault Core] Stage 1: Infrastructure Bootstrap (VM + TLS)..."
					terraform_layer_executor "${layer}" "-target=module.vault_tls -target=module.vault_compute"          
					
					echo ">>> [Vault Core] Stage 2: Service Configuration (PKI)..."
          # Since Stage 1 just done and to prevent drift bug from Provider, Terraform does not need to scan KVM.
					terraform_layer_executor "${layer}" "-target=module.vault_pki_config -refresh=false"
      else
          terraform_layer_executor "${layer}"
      fi
      
      execution_time_reporter
      break
    else
      echo "Invalid option $REPLY"
    fi
  done
}