#!/bin/bash

# This script contains functions for controlling KVM/libvirt services and VMs.

# Project code filter that matches project_code in L00 terraform.tfvars
readonly PROJECT_CODE="core"

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

# Function: Forcefully clean up all libvirt resources with project_code = PROJECT_CODE.
libvirt_resource_purger() {
  log_print "STEP" "Detecting and purging all resources with project_code = '${PROJECT_CODE}'..."

  # 1. Purge VMs (Domains) starting with PROJECT_CODE-
  log_print "STEP" "Purging Virtual Machines (Domains)..."
  for vm in $(sudo virsh list --all --name | grep "^${PROJECT_CODE}-" || true); do
    if [[ -n "$vm" ]]; then
      log_print "TASK" "Destroying and undefining VM: $vm"
      sudo virsh destroy "$vm" >/dev/null 2>&1 || true
      sudo virsh undefine "$vm" --nvram --remove-all-storage >/dev/null 2>&1 || true
    fi
  done

  # 2. Purge Storage Volumes and Pools starting with PROJECT_CODE-
  log_print "STEP" "Purging Storage Volumes and Pools..."
  for pool in $(sudo virsh pool-list --all --name | grep "^${PROJECT_CODE}-" || true); do
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

  # 3. Purge Networks starting with PROJECT_CODE-
  log_print "STEP" "Purging Networks..."
  for net in $(sudo virsh net-list --all --name | grep "^${PROJECT_CODE}-" || true); do
    if sudo virsh net-info "$net" >/dev/null 2>&1; then
      log_print "TASK" "Destroying and undefining network: $net"
      sudo virsh net-destroy "$net" >/dev/null 2>&1 || true
      sudo virsh net-undefine "$net" >/dev/null 2>&1 || true
    fi
  done

  log_divider
  log_print "OK" "Libvirt resource purge complete."
  log_divider
}
