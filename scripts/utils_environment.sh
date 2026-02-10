#!/bin/bash

# Function: Scans project directories to find all Packer and Terraform layers.
iac_layer_discoverer() {
  log_print "STEP" "Discovering Packer Base and Terraform layers..."
  cd "${SCRIPT_DIR}" || return 1

  # Discover Packer Layers
  local packer_layers_str=""
  if [ -d "${PACKER_DIR}" ]; then
    packer_layers_str=$(find "${PACKER_DIR}" -maxdepth 1 -name "*.pkrvars.hcl" ! -name "values.pkrvars.hcl" -printf '%f\n' | \
      sed 's/\.pkrvars\.hcl//g' | \
      sort | \
      tr '\n' ' ') 
  fi
  # Remove trailing space
  env_var_mutator "ALL_PACKER_BASES" "${packer_layers_str% }"

  # Discover Terraform Layers
  local terraform_layers_str=""
  if [ -d "${TERRAFORM_DIR}/layers" ]; then
    terraform_layers_str=$(find "${TERRAFORM_DIR}/layers" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | \
      sort | \
      tr '\n' ' ')
  fi
  env_var_mutator "ALL_TERRAFORM_LAYERS" "${terraform_layers_str% }"
  
  log_print "INFO" "Layer discovery complete and .env updated."
}

# Function: Check the host operating system
host_os_detail_handler() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID_LIKE" == *"fedora"* || "$ID" == "fedora" || "$ID" == "rhel" || "$ID" == "centos" ]]; then
      export HOST_OS_FAMILY="rhel"
    elif [[ "$ID_LIKE" == *"debian"* || "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
      export HOST_OS_FAMILY="debian"
    else
      export HOST_OS_FAMILY="unknown"
    fi
    export HOST_OS_VERSION_ID="${VERSION_ID%%.*}" # Get major version
  else
    export HOST_OS_FAMILY="unknown"
    export HOST_OS_VERSION_ID="unknown"
  fi
}

# Function: Check for CPU hardware virtualization support (VT-x or AMD-V).
cpu_virt_support_checker() {
  if grep -E -q '^(vmx|svm)' /proc/cpuinfo; then
    export VIRT_SUPPORTED="true"
  else
    export VIRT_SUPPORTED="false"
  fi
}

# Function: Configure Packer network settings based on strategy
packer_net_configurator() {
	local strategy="${1:-$ENVIRONMENT_STRATEGY}"
  local bridge_val=""
  local device_val="virtio-net"

  if [[ "$strategy" == "container" ]]; then
    log_print "WARN" "Container strategy detected. Forcing User Mode Networking (SLIRP) for Packer."
    bridge_val=""
  elif ip link show virbr0 >/dev/null 2>&1; then
    bridge_val="virbr0"
    log_print "INFO" "Network Mode: Bridge detected (virbr0). Using performance networking."
  else
    log_print "WARN" "'virbr0' bridge not found. Defaulting to user-mode/SLIRP networking."
    bridge_val=""
  fi

  env_var_mutator "PKR_VAR_NET_BRIDGE" "${bridge_val}"
  env_var_mutator "PKR_VAR_NET_DEVICE" "${device_val}"
}

env_file_bootstrapper() {
  local detected_root="$1"

  local env_path="${detected_root}/.env"

  # 1. Prepare the variables.
  local current_uid=$(id -u)
  local current_gid=$(id -g)
  local current_uname=$(whoami)
  local current_libvirt_gid
  
  if getent group libvirt > /dev/null 2>&1; then
    current_libvirt_gid=$(getent group libvirt | cut -d: -f3)
  else
    log_print "WARN" "'libvirt' group not found on host. Using default GID 999."
    current_libvirt_gid=999
  fi

  # 2. Process vs update
	# 2.1. If .env does not exist, create a new one.
  if [[ ! -f "$env_path" ]]; then
    log_print "INFO" "Creating new .env file at ${env_path}..."
    
    cat > "$env_path" <<EOF
# Project Root (Auto-detected)
PROJECT_ROOT="${detected_root}"

# Core Strategy Selection: "container" or "native"
ENVIRONMENT_STRATEGY="native"

# Discovered Packer Base and Terraform Layers
ALL_PACKER_BASES=""
ALL_TERRAFORM_LAYERS=""

# Vault Configuration
DEV_VAULT_ADDR="https://127.0.0.1:8200"
DEV_VAULT_CACERT="\${PROJECT_ROOT}/vault/tls/ca.pem"
DEV_VAULT_CACERT_PODMAN="\${PROJECT_ROOT}/vault/tls/ca.pem"
DEV_VAULT_TOKEN=""

# User and SSH Configuration
SSH_PRIVATE_KEY="\${HOME}/.ssh/id_ed25519_on-premise-gitlab-deployment"

# Container Runtime Environment
HOST_UID=${current_uid}
HOST_GID=${current_gid}
UNAME=${current_uname}
UHOME=\${HOME}

# For Unpriviledged Podman
PKR_VAR_NET_BRIDGE=""
PKR_VAR_NET_DEVICE="virtio-net"

# For Podman on Ubuntu/RHEL to get the GID of the libvirt group
LIBVIRT_GID=${current_libvirt_gid}
EOF
    log_print "OK" ".env file created successfully."

  else
    # 2.2. If .env exists, update the variables.
    local saved_root
    saved_root=$(grep "^PROJECT_ROOT=" "$env_path" | cut -d'=' -f2 | tr -d '"')
    if [[ "$saved_root" != "$detected_root" ]]; then
      log_print "WARN" "Project location changed. Updating PROJECT_ROOT..."
      # 2.2.1 If PROJECT_ROOT does not exist in the old file, append it, otherwise replace it.
      if grep -q "^PROJECT_ROOT=" "$env_path"; then
				sed -i "s|^PROJECT_ROOT=.*|PROJECT_ROOT=\"${detected_root}\"|" "$env_path"
      else
				# 2.2.2 Insert at the first line to make it look better.
				sed -i "1i PROJECT_ROOT=\"${detected_root}\"" "$env_path"
      fi
    fi

    # 2.3 Update UID/GID (handle user switching or Libvirt GID changes)
    env_var_mutator "HOST_UID" "${current_uid}"
    env_var_mutator "HOST_GID" "${current_gid}"
    env_var_mutator "LIBVIRT_GID" "${current_libvirt_gid}"
    
    # 2.4 Ensure DEV_VAULT_CACERT uses the new variable format. Force it to use the ${PROJECT_ROOT} variable format.
    if grep -q "DEV_VAULT_CACERT=" "$env_path"; then
        sed -i "s|^DEV_VAULT_CACERT=.*|DEV_VAULT_CACERT=\"\${PROJECT_ROOT}/vault/tls/ca.pem\"|" "$env_path"
    fi
  fi

  # 4. Perform discovery
  iac_layer_discoverer

  # 5. Network config
  local current_strategy
  current_strategy=$(grep "^ENVIRONMENT_STRATEGY=" "$env_path" | cut -d'=' -f2 | tr -d '"')
  packer_net_configurator "${current_strategy:-native}"
}

# Function to update a specific variable in the .env file
env_var_mutator() {
  cd "${SCRIPT_DIR}" || exit 1
  local key="$1"
  local value="$2"
  # This sed command finds the key and replaces its value, handling paths with slashes.
    sed -i "s|^\\(${key}\\s*=\\s*\\).*|\\1\"${value}\"|" .env
}

# Function to handle the interactive strategy switching
switch_strategy() {
  local var_name="$1"
  local new_value="$2"
  
  env_var_mutator "$var_name" "$new_value"
  log_print "INFO" "Strategy '${var_name}' in .env updated to '${new_value}'."
  cd "${SCRIPT_DIR}" && exec ./entry.sh
}

strategy_switch_handler() {
  echo
  log_print "INFO" "Switching strategy..."
  log_print "INFO" "Cleaning Terraform plugins/cache (keeping state)..."
  (cd "${TERRAFORM_DIR}" && rm -rf .terraform .terraform.lock.hcl) 
  
	log_divider

  local new_strategy
  new_strategy=$([[ "$ENVIRONMENT_STRATEGY" == "container" ]] && echo "native" || echo "container")

  # Configure Packer network settings based on strategy
  packer_net_configurator "${new_strategy}"
  switch_strategy "ENVIRONMENT_STRATEGY" "$new_strategy"
}
