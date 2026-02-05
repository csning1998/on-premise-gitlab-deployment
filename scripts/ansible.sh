#!/bin/bash

# Extracts confidential variables from Vault for specific playbooks.
vault_secret_extractor() {
  local playbook_file="$1"
  local extra_vars_string=""
  local secrets_json
  
  # Define an array to store configurations, format: "VAULT_PATH|KEY1 KEY2 KEY3"
  local vault_clusters=()

  # 1. Determine the configurations (paths and keys) by playbook
  case "${playbook_file}" in
    "10-provision-vault.yaml")
      log_print "INFO" "Vault playbook detected. Preparing credentials..." >&2
      vault_clusters+=(
        "secret/on-premise-gitlab-deployment/infrastructure|vault_keepalived_auth_pass vault_haproxy_stats_pass"
      )
      ;;
    "20-provision-data-services.yaml")
      log_print "INFO" "Data Services playbook detected. Preparing credentials..." >&2

      # Path 1: GitLab Databases
      vault_clusters+=(
        "secret/on-premise-gitlab-deployment/gitlab/databases|pg_superuser_password pg_replication_password pg_vrrp_secret redis_requirepass redis_masterauth redis_vrrp_secret minio_root_password minio_vrrp_secret minio_root_user"
      )
      # Path 2: Harbor Databases
      vault_clusters+=(
        "secret/on-premise-gitlab-deployment/harbor/databases|pg_superuser_password pg_replication_password pg_vrrp_secret redis_requirepass redis_masterauth redis_vrrp_secret minio_root_password minio_vrrp_secret minio_root_user"
      )
      # Path 3: Dev Harbor App
      vault_clusters+=(
        "secret/on-premise-gitlab-deployment/dev-harbor/app|dev_harbor_admin_password dev_harbor_pg_db_password"
      )
      ;;
    "30-provision-microk8s.yaml")
      log_print "INFO" "MicroK8s playbook detected. Preparing credentials..." >&2
      vault_clusters+=(
        "secret/on-premise-gitlab-deployment/databases|redis_requirepass"
      )
      ;;
    "40-provision-harbor.yaml")
      log_print "INFO" "Harbor playbook detected. Preparing credentials..." >&2
      vault_clusters+=(
        "secret/on-premise-gitlab-deployment/harbor|harbor_admin_password harbor_pg_db_password"
      )
      ;;
    *)
      echo "${extra_vars_string}"
      return 0
      ;;
  esac

  # 2. Iterate through each configuration config
  for config in "${vault_clusters[@]}"; do
    # Parse the string: extract Path and Keys
    local vault_path="${config%%|*}"    # Get the string on the left of |
    local keys_str="${config#*|}"       # Get the string on the right of |
    local keys_needed=(${keys_str})     # Convert the string to an array

    # Fetch secrets for this specific path
    if ! secrets_json=$(vault kv get -address="${VAULT_ADDR}" -ca-cert="${VAULT_CACERT}" -format=json "${vault_path}"); then
      log_print "FATAL" "Failed to fetch secrets from Vault at path '${vault_path}'. Is Vault unsealed?"
      return 1
    fi

    # 3. Process Keys for this path
    for key in "${keys_needed[@]}"; do
      local value
      value=$(echo "${secrets_json}" | jq -r ".data.data.${key}")

      if [[ -z "${value}" || "${value}" == "null" ]]; then
        log_print "FATAL" "Could not find required key '${key}' in Vault at '${vault_path}'."
        return 1
      fi

      extra_vars_string+=" --extra-vars '${key}=${value}'"
    done
  done

  log_print "OK" "Credentials fetched successfully." >&2
  
  echo "${extra_vars_string}"
  return 0
}

# [Dev] This function is for faster reset and re-execute the Ansible Playbook
ansible_playbook_executor() {
  local playbook_file="$1"  # (e.g., "30-provision-kubeadm.yaml").
  local inventory_file="$2" # (e.g., "inventory-30-gitlab-kubeadm.yaml").

  if [ -z "$playbook_file" ] || [ -z "$inventory_file" ]; then
    log_print "FATAL" "Playbook or inventory file not specified for ansible_playbook_executor function."
    return 1
  fi

  local private_key_path="${SSH_PRIVATE_KEY}"
  local relative_inventory_path="ansible/${inventory_file}"
  local relative_playbook_path="ansible/playbooks/${playbook_file}"
  local full_inventory_path="${SCRIPT_DIR}/${relative_inventory_path}"

  if [ ! -f "${SCRIPT_DIR}/${relative_playbook_path}" ]; then
    log_print "FATAL" "Playbook not found at '${relative_playbook_path}'"
    return 1
  fi
  if [ ! -f "${full_inventory_path}" ]; then
    log_print "FATAL" "Inventory not found at '${full_inventory_path}'"
    return 1
  fi

	# Select the environment context based on the playbook file prefix
	# [Dev] 01-09: Dev Vault (Local)
	# [Prod] 20-: Prod Vault (Layer10)
  local layer_prefix
  layer_prefix=$(echo "$playbook_file" | grep -oE '^[0-9]+' | head -n1)

  local target_context="dev"
  if [[ -n "$layer_prefix" && "$layer_prefix" -ge 20 ]]; then
    target_context="prod"
  fi

  vault_context_handler "$target_context"

  log_print "STEP" "Running Ansible Playbook [${playbook_file}] with inventory [${inventory_file}]"

  local extra_vars
  if ! extra_vars=$(vault_secret_extractor "${playbook_file}"); then
    return 1  # the extractor func will print its err
  fi

  local cmd="ansible-playbook \
    -i ${relative_inventory_path} \
    --private-key ${private_key_path} \
    ${extra_vars} \
    ${relative_playbook_path} \
    -vv"

  run_command "${cmd}" "${SCRIPT_DIR}"
  log_print "OK" "Playbook execution finished."
}

# Function: Display a sub-menu to select and run a Playbook based on Inventory.
ansible_menu_handler() {
  local inventory_options=()
  local inventory_dir="${ANSIBLE_DIR}" 

  # [Fix] Updated glob pattern to match new naming convention (e.g., inventory-redis-gitlab.yaml)
  for f in "${inventory_dir}/inventory-"*.yaml; do
    if [ -e "$f" ]; then
      inventory_options+=("$(basename "$f")")
    fi
  done
  inventory_options+=("Back to Main Menu")

  PS3=$'\n\033[1;34m[INPUT] Select a Cluster Inventory to run its Playbook: \033[0m'
  select inventory in "${inventory_options[@]}"; do
    
    if [ "$inventory" == "Back to Main Menu" ]; then
      log_print "INFO" "Returning to main menu..."
      break
    
    elif [ -n "$inventory" ]; then
      
      # Logic to parse 'inventory-<component>-<platform>-<service>.yaml' by removing prefix and suffix
      local filename_base=${inventory#inventory-}
      filename_base=${filename_base%.yaml}         # e.g. 30-gitlab-kubeadm

      # Extract the component (first word before the hyphen)
      local playbook_prefix=${filename_base%%-*}   # 30
      local target_service=${filename_base#*-}     # gitlab-kubeadm
      local playbook=""

      case "$playbook_prefix" in
        "10")
          playbook="10-provision-vault.yaml"
          ;;
        "20")
          playbook="20-provision-data-services.yaml"
          ;;
        "30")
          case "$target_service" in
            *kubeadm*)
              playbook="30-provision-kubeadm.yaml"
              ;;
            *microk8s*)
              playbook="30-provision-microk8s.yaml"
              ;;
            *)
              log_print "WARN" "Unknown k8s variant in '${target_service}', defaulting to kubeadm"
              playbook="30-provision-kubeadm.yaml"
              ;;
          esac
          ;;
        *)
          log_print "WARN" "Unknown prefix '${playbook_prefix}' in '${inventory}'"
          playbook="10-provision-${target_service}.yaml"  # fallback
          ;;
      esac
      
      log_divider
      log_print "INFO" "Selected Inventory: ${inventory}"
      log_print "INFO" "Derived Service:    ${target_service}"
      log_print "INFO" "Mapped Playbook:    ${playbook}"
      log_divider
      
      if [ ! -f "${ANSIBLE_DIR}/playbooks/${playbook}" ]; then
        log_print "FATAL" "Mapped playbook '${playbook}' does not exist at ${ANSIBLE_DIR}/playbooks/${playbook}"
        continue
      fi

      ansible_playbook_executor "$playbook" "$inventory"
      break

    else
      log_print "ERROR" "Invalid option $REPLY"
      continue
    fi
  done
}
