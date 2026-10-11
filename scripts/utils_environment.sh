#!/bin/bash

# Function: Scans project directories to find all Packer and Terraform layers.
iac_layer_discoverer() {
  log_print "STEP" "Discovering Packer Base and Terraform layers..."
  cd "${SCRIPT_DIR}" || return 1

  # Discover Packer Layers
  local packer_layers_str=""
  if [ -d "${PACKER_DIR}" ]; then
    packer_layers_str=$(find "${PACKER_DIR}" -mindepth 2 -maxdepth 2 -name "*.pkrvars.hcl" ! -name "values.pkrvars.hcl" -printf '%f\n' | \
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
    if [[ "$ID" == *"fedora"* || "$ID" == "fedora" || "$ID" == "rhel" || "$ID" == "centos" ]]; then
      export HOST_OS_FAMILY="rhel"
    elif [[ "$ID" == *"debian"* || "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
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

# Function: Configure Packer network settings based on the host bridge
packer_net_configurator() {
  local bridge_val=""
  local device_val="virtio-net"

  if ip link show virbr0 >/dev/null 2>&1; then
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

  # 1. Process vs update
  # 1.1. If .env does not exist, create a new one.
  if [[ ! -f "$env_path" ]]; then
    log_print "INFO" "Creating new .env file at ${env_path}..."

    cat > "$env_path" <<EOF
# Project Root (Auto-detected)
PROJECT_ROOT="${detected_root}"

# Discovered Packer Base and Terraform Layers
ALL_PACKER_BASES=""
ALL_TERRAFORM_LAYERS=""

# User and SSH Configuration
SSH_PRIVATE_KEY="\${HOME}/.ssh/id_ed25519_on-premise-gitlab-deployment"

# Packer Network Configuration
PKR_VAR_NET_BRIDGE=""
PKR_VAR_NET_DEVICE="virtio-net"
EOF
    log_print "OK" ".env file created successfully."

  else
    # 1.2. If .env exists, update the variables.
    local saved_root
    saved_root=$(grep "^PROJECT_ROOT=" "$env_path" | cut -d'=' -f2 | tr -d '"')
    if [[ "$saved_root" != "$detected_root" ]]; then
      log_print "WARN" "Project location changed. Updating PROJECT_ROOT..."
      # 1.2.1 If PROJECT_ROOT does not exist in the old file, append it, otherwise replace it.
      if grep -q "^PROJECT_ROOT=" "$env_path"; then
        sed -i "s|^PROJECT_ROOT=.*|PROJECT_ROOT=\"${detected_root}\"|" "$env_path"
      else
        # 1.2.2 Insert at the first line to make it look better.
        sed -i "1i PROJECT_ROOT=\"${detected_root}\"" "$env_path"
      fi
    fi
  fi

  # 2. Perform discovery
  iac_layer_discoverer

  # 3. Network config
  packer_net_configurator
}

# Function to update a specific variable in the .env file
env_var_mutator() {
  cd "${SCRIPT_DIR}" || exit 1
  local key="$1"
  local value="$2"
  # This sed command finds the key and replaces its value, handling paths with slashes.
    sed -i "s|^\\(${key}\\s*=\\s*\\).*|\\1\"${value}\"|" .env
}
