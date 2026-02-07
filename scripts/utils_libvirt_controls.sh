#!/bin/bash

# This script contains functions for controlling KVM/libvirt services and VMs.

# Resources Mapping
declare -A DOMAIN_MAP=(
	["10-vault-raft"]="vault-raft"

	["30-gitlab-postgres"]="gitlab-postgres-"
	["30-gitlab-redis"]="gitlab-redis-"
	["30-gitlab-minio"]="gitlab-minio-"
	["40-gitlab-kubeadm"]="gitlab-kubeadm-"

	["30-harbor-postgres"]="harbor-postgres-"
	["30-harbor-redis"]="harbor-redis-"
	["30-harbor-minio"]="harbor-minio-"
	["40-harbor-microk8s"]="harbor-microk8s-"
)

# Storage Pool names.
declare -A POOL_MAP=(
	["10-vault-raft"]="iac-vault-raft"
	["30-gitlab-postgres"]="iac-gitlab-postgres"
	["30-gitlab-redis"]="iac-gitlab-redis"
	["30-gitlab-minio"]="iac-gitlab-minio"
	["40-gitlab-kubeadm"]="iac-gitlab-kubeadm"

	["30-harbor-postgres"]="iac-harbor-postgres"
	["30-harbor-redis"]="iac-harbor-redis"
	["30-harbor-minio"]="iac-harbor-minio"
	["40-harbor-microk8s"]="iac-harbor-microk8s"
)

# Network prefixes.
declare -A NET_MAP=(
	["10-vault-raft"]="iac-vault-raft"
	["30-gitlab-postgres"]="iac-gitlab-postgres"
	["30-gitlab-redis"]="iac-gitlab-redis"
	["30-gitlab-minio"]="iac-gitlab-minio"
	["40-gitlab-kubeadm"]="iac-gitlab-kubeadm"

	["30-harbor-postgres"]="iac-harbor-postgres"
	["30-harbor-redis"]="iac-harbor-redis"
	["30-harbor-minio"]="iac-harbor-minio"
	["40-harbor-microk8s"]="iac-harbor-microk8s"
)

# Function: Ensure libvirt service is running before executing a command.
libvirt_service_manager() {
  log_print "INFO" "Checking status of libvirt service..."

  # Use 'is-active' for a clean check without parsing text.
  if ! sudo systemctl is-active --quiet libvirtd; then
    log_print "WARN" "libvirt service is not running. Attempting to start it..."
    
    # Use 'sudo' as this is a system-level service.
    if sudo systemctl start libvirtd; then
      log_print "OK" "libvirt service started successfully."
      # Give the service a moment to initialize networks.
      sleep 2
    else
      log_print "FATAL" "Failed to start libvirt service. Please check 'systemctl status libvirtd'."
      # Exit the script if the core dependency cannot be started.
      exit 1
    fi
  else
    log_print "OK" "libvirt service is already running."
  fi
}

# Function: Forcefully clean up all libvirt resources associated with this project.
libvirt_resource_purger() {
  if [[ $# -eq 0 ]]; then
    log_print "ERROR" "Usage: $0 <target1> [target2...] | all"
    log_print "INFO" "Available targets: ${!DOMAIN_MAP[*]}"
    return 1
  fi

  local targets_to_process=("$@")
  local domain_prefixes_to_purge=()
  local pool_names_to_purge=()
  local net_prefixes_to_purge=()

  # 1. Build lists of resources to purge based on input
  log_print "STEP" "Parsing targets and building resource lists..."
  for target in "${targets_to_process[@]}"; do
    if [[ "$target" == "all" ]]; then
      log_print "INFO" "Target 'all' selected. Preparing to purge all known resources."
      domain_prefixes_to_purge+=("${DOMAIN_MAP[@]}")
      pool_names_to_purge+=("${POOL_MAP[@]}")
      net_prefixes_to_purge+=("${NET_MAP[@]}")
      break # 'all' overrides everything else
    fi

    if [[ -v "DOMAIN_MAP[$target]" ]]; then
      log_print "INFO" "Adding resources for target: $target"
      domain_prefixes_to_purge+=("${DOMAIN_MAP[$target]}")
      pool_names_to_purge+=("${POOL_MAP[$target]}")
      net_prefixes_to_purge+=("${NET_MAP[$target]}")
    else
      log_print "WARN" "Unknown target '$target'. Skipping."
    fi
  done

  # 2. Deduplicate the resource lists
  local unique_domain_prefixes
	unique_domain_prefixes="$(echo "${domain_prefixes_to_purge[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
  
	local unique_pool_names
	unique_pool_names="$(echo "${pool_names_to_purge[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"
  
	local unique_net_prefixes
	unique_net_prefixes="$(echo "${net_prefixes_to_purge[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

  # 3. Purge VMs (Domains)
  log_print "STEP" "Purging Virtual Machines (Domains)..."
  for prefix in ${unique_domain_prefixes}; do
    for vm in $(sudo virsh list --all --name | grep "^${prefix}" || true); do
      if [[ -n "$vm" ]]; then
        log_print "TASK" "Destroying and undefining VM: $vm"
        sudo virsh destroy "$vm" >/dev/null 2>&1 || true
        sudo virsh undefine "$vm" --nvram --remove-all-storage >/dev/null 2>&1 || true
      fi
    done
  done

  # 4. Purge Storage Volumes and Pools
  log_print "STEP" "Purging Storage Volumes and Pools..."
  for pool in ${unique_pool_names}; do
    if sudo virsh pool-info "$pool" >/dev/null 2>&1; then
      # Delete all volumes within the pool
      for vol in $(sudo virsh vol-list "$pool" | awk 'NR>2 {print $1}' || true); do
        if [[ -n "$vol" ]]; then
          log_print "TASK" "Deleting volume: $vol from pool $pool"
          sudo virsh vol-delete --pool "$pool" "$vol" >/dev/null 2>&1 || true
        fi
      done
      # Destroy and undefine the pool itself
      log_print "TASK" "Destroying and undefining pool: $pool"
      sudo virsh pool-destroy "$pool" >/dev/null 2>&1 || true
      sudo virsh pool-undefine "$pool" >/dev/null 2>&1 || true
    else
      log_print "INFO" "Storage pool $pool does not exist, skipping."
    fi
  done

  # 5. Purge Networks
  log_print "STEP" "Purging Networks..."
  for prefix in ${unique_net_prefixes}; do
    for suffix in "nat" "nat-net" "hostonly" "hostonly-net"; do
      local net_name="${prefix}-${suffix}"
      if sudo virsh net-info "$net_name" >/dev/null 2>&1; then
        log_print "TASK" "Destroying and undefining network: $net_name"
        sudo virsh net-destroy "$net_name" >/dev/null 2>&1 || true
        sudo virsh net-undefine "$net_name" >/dev/null 2>&1 || true
      fi
    done
  done

  log_divider
  log_print "OK" "Libvirt resource purge complete."
  log_divider
}
