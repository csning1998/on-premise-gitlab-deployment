#!/bin/bash

# This script contains functions for managing Terraform resources.

# Function: Clean up a specific Terraform layer's state files.
# Parameter 1: The short name of the layer (e.g., "10-provision-kubeadm") or "all".
terraform_artifact_cleaner() {
  local target_layer="$1"
  if [ -z "$target_layer" ]; then
    log_print "FATAL" "No Terraform layer specified for terraform_artifact_cleaner function."
    log_print "INFO" "Available layers: ${ALL_LAYERS[*]}"
    return 1
  fi

  local layers_to_clean=()
  if [[ "$target_layer" == "all" ]]; then
    log_print "STEP" "Preparing to clean all Terraform layers..."
    layers_to_clean=("${ALL_LAYERS[@]}")
  else
    layers_to_clean=("$target_layer")
  fi

  for layer_name in "${layers_to_clean[@]}"; do
    local layer_dir="${TERRAFORM_DIR}/layers/${layer_name}"

    if [[ ! -d "$layer_dir" ]]; then
      log_print "WARN" "Terraform layer directory not found, skipping: ${layer_dir}"
      continue
    fi

		if [[ "$layer_name" == "20-gitlab-minio" || "$layer_name" == "20-harbor-minio" || "$layer_name" == "50-harbor-provision" ]]; then
			log_print "STEP" "Cleaning Terraform artifacts for layer [${layer_name}]..."
			rm -rf "${layer_dir}/.terraform.lock.hcl" \
				"${layer_dir}/terraform.tfstate" \
				"${layer_dir}/terraform.tfstate.backup"

			log_print "INFO" "Terraform artifact cleanup for [${layer_name}] completed."
		fi

    log_divider
  done
}

# Function: Apply a Terraform configuration for a specific layer.
terraform_layer_executor() {
  local layer_name="$1"          # Parameter 1: The short name of the layer.
  local target_resource="${2:-}" # Parameter 2 (Optional): A specific resource target.

  if [ -z "$layer_name" ]; then
    log_print "FATAL" "No Terraform layer specified for terraform_layer_executor function."
    return 1
  fi

  local layer_dir="${TERRAFORM_DIR}/layers/${layer_name}"
  if [ ! -d "$layer_dir" ]; then
    log_print "FATAL" "Terraform layer directory not found: ${layer_dir}"
    return 1
  fi

  log_print "STEP" "Applying Terraform configuration for layer [${layer_name}]..."

  # 1. Define Base Commands
  local cmd_init="terraform init -upgrade"
  local cmd_destroy="terraform destroy -auto-approve -var-file=./terraform.tfvars"
  local cmd_apply="terraform apply -auto-approve -var-file=./terraform.tfvars"

  # 2. Handle Target Resource (if specified, append to destroy/apply commands)
  if [ -n "$target_resource" ]; then
    log_print "INFO" "Targeting resource: ${target_resource}"
    cmd_destroy+=" ${target_resource}"
    cmd_apply+=" ${target_resource}"
  fi

  local cmd=""

  # 3. Construct Execution Chain based on Layer Type
  # [Special Logic] Github Meta Layer: Import + Apply ONLY (Skip Destroy)
  if [[ "$layer_name" == "90-github-meta" ]]; then
    log_print "WARN" "Github Meta Layer detected: SKIPPING DESTROY phase to preserve repository."
    log_print "TASK" "Checking and Importing existing repository if needed..."
    
    # Init -> Check State -> Import if missing
    local cmd_import="(terraform state list | grep -q 'github_repository.this' || terraform import github_repository.this on-premise-gitlab-deployment)"
    
    # Chain: Init -> Import (if needed) -> Apply
    cmd="${cmd_init} && ${cmd_import} && ${cmd_apply}"

  else
    # Chain: Init -> Destroy -> Init -> Apply
    cmd="${cmd_init} && ${cmd_destroy} && ${cmd_init} && ${cmd_apply}"
  fi

  # 4. Execute the constructed command chain
  run_command "${cmd}" "${layer_dir}"

  log_print "OK" "Terraform apply for [${layer_name}] complete."
  log_divider
}

# Function: Display a sub-menu to select a Terraform layer for a full rebuild.
terraform_layer_selector() {
  local layer_options=("${ALL_TERRAFORM_LAYERS[@]}" "Back to Main Menu")

  # Use log_print for the prompt before 'select' if desired, 
  # but 'select' uses PS3. We can keep PS3 simple or colorized.
  PS3=$'\n\033[1;34m[INPUT] Select a Terraform layer to REBUILD: \033[0m'
  
  select layer in "${layer_options[@]}"; do
    if [[ "$layer" == "Back to Main Menu" ]]; then
      log_print "INFO" "Returning to main menu..."
      break

    elif [[ " ${ALL_TERRAFORM_LAYERS[*]} " == *"${layer}"* ]]; then
      log_print "STEP" "Executing Full Rebuild for [${layer}]..."
      if ! ssh_key_verifier; then break; fi
      libvirt_resource_purger "${layer}"
      libvirt_service_manager
      terraform_artifact_cleaner "${layer}"
      
      if [[ "$layer" == "10-vault-core" ]]; then
				log_print "WARN" "[Vault Core] Detected complex layer. Initiating 2-Stage Bootstrap..."
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

				log_print "TASK" "[Vault Core] Stage 1: Infrastructure Bootstrap (VM + TLS)..."
				terraform_layer_executor "${layer}" "-target=module.vault_tls_gen -target=module.vault_cluster"          
				
				log_print "TASK" "[Vault Core] Stage 2: Service Configuration (PKI)..."
				# Since Stage 1 just done and to prevent drift bug from Provider, Terraform does not need to scan KVM.
				terraform_layer_executor "${layer}" "-target=module.vault_pki_setup -target=module.vault_workload_identity_components -target=module.vault_workload_identity_dependencies -refresh=false"
				
				cd "${TERRAFORM_DIR}/layers/10-vault-core" && terraform refresh -var-file=terraform.tfvars
				cd "${SCRIPT_DIR}" || exit
      else
          terraform_layer_executor "${layer}"
      fi
      
      execution_time_reporter
      break
    else
      log_print "ERROR" "Invalid option $REPLY"
    fi
  done
}
