#!/bin/bash

# This script contains general utility and helper functions.

readonly SSH_CONFIG="$HOME/.ssh/config"

# Function: Check if the required SSH private key exists
ssh_key_verifier() {
  if [ -z "$SSH_PRIVATE_KEY" ]; then
      log_print "ERROR" "SSH_PRIVATE_KEY variable is not set."
      return 1
  fi

  if [ ! -f "$SSH_PRIVATE_KEY" ]; then
    log_print "ERROR" "SSH private key for automation not found at '$SSH_PRIVATE_KEY'"
    log_print "INFO" "Please use the 'Generate SSH Key' menu option first, or configure the correct key name in 'scripts/config.sh'."
    return 1
  fi
  # If the key exists, return success (0)
  return 0
}

# Function: Generate an SSH key for IaC automation (unattended mode)
ssh_key_generator_handler() {
  local default_key_name="id_ed25519_on-premise-gitlab-deployment"
  local key_name

  log_print "INFO" "This utility will generate an SSH key for IaC automation (unattended mode)."
  
  log_print "INPUT" "Enter the desired key name (default: ${default_key_name}): "
  read -r key_name
  
  key_name=${key_name:-$default_key_name}
  
  local private_key_path="${HOME}/.ssh/${key_name}"
  local public_key_path="${private_key_path}.pub"

  if [ -f "$private_key_path" ]; then
    log_print "WARN" "Key file '${private_key_path}' already exists."
    
    log_print "INPUT" "Overwrite? (y/n): "
    read -r overwrite_answer
    
    if [[ ! "$overwrite_answer" =~ ^[Yy]$ ]]; then
      log_print "INFO" "Skipping key generation."
      return
    fi
  fi

  log_print "TASK" "Generating key at '${private_key_path}'..."
  ssh-keygen -t ed25519 -f "$private_key_path" -C "$key_name" -N ""
  
  log_print "OK" "Key generated successfully."
  ls -l "$private_key_path" "$public_key_path"
  log_divider
  
  log_print "TASK" "Updating SSH_PRIVATE_KEY in .env file to: ${private_key_path}"
  # Call the helper function to update the .env file
  env_var_mutator "SSH_PRIVATE_KEY" "${private_key_path}"

  log_print "WARN" "IMPORTANT: Please update your configuration file"
  log_print "WARN" "  e.g., in 'packer/secret.auto.pkrvars.hcl' or terraform/*.tfvars"
  log_print "WARN" "to use the following paths:"
  log_print "INFO" "In Terraform: ssh_private_key_path = \"${private_key_path}\""
  log_print "INFO" "In Packer: ssh_public_key_path  = \"${public_key_path}\""
  log_divider
}

# Function: Verify SSH access to hosts defined in ~/.ssh/on-premise-gitlab-deployment_config
ssh_connection_verifier() {
  log_print "STEP" "Performing strict SSH access verification for all IaC configurations..."

  local ssh_config_file
  # Use an array to handle cases where no files are found
  readarray -t ssh_config_files < <(find "$HOME/.ssh" -maxdepth 1 -name "iac-kubeadm-*_config")

  if [ ${#ssh_config_files[@]} -eq 0 ]; then
    log_print "ERROR" "No IaC SSH config files found matching '$HOME/.ssh/iac-kubeadm-*_config'."
    return 1
  fi

  local all_checks_passed=true

  for ssh_config_file in "${ssh_config_files[@]}"; do
    log_divider
    log_print "INFO" "Verifying configuration: $(basename "${ssh_config_file}")"

    # Dynamically extract the UserKnownHostsFile from the config itself.
    local raw_path
    raw_path=$(awk '/UserKnownHostsFile/ {print $2; exit}' "${ssh_config_file}")

    # Manually expand the tilde (~) to the user's home directory.
    local known_hosts_file="${raw_path/#\~/$HOME}"

    if [ ! -f "${known_hosts_file}" ]; then
      log_print "ERROR" "Known hosts file not found at ${known_hosts_file}"
      log_print "INFO" "Please ensure the corresponding Terraform layer has been applied successfully."
      all_checks_passed=false
      continue # Skip to the next config file
    fi

    local all_hosts
    all_hosts=$(awk '/^Host / {print $2}' "${ssh_config_file}")

    if [ -z "${all_hosts}" ]; then
      log_print "WARN" "No hosts found in ${ssh_config_file}"
      continue
    fi

    # Loop through each host and test the connection silently.
    while IFS= read -r host; do
      if [ -z "$host" ]; then continue; fi
      
      log_print "TASK" "Verifying connection to host: ${host}..."
      # Use ssh with the 'true' command for a quick, non-interactive connection test.
      # The '-n' option is CRITICAL here to prevent ssh from consuming the stdin of the while loop.
      if ssh -n \
          -F "${ssh_config_file}" \
          -o ConnectTimeout=5 \
          -o BatchMode=yes \
          -o PasswordAuthentication=no \
          -o StrictHostKeyChecking=yes \
          -o UserKnownHostsFile="${known_hosts_file}" \
        "$host" true 2>/dev/null; then
        log_print "OK" "Connected to ${host} via public key."
      else
        log_print "ERROR" "Could not connect to ${host} using strict key-based authentication."
        all_checks_passed=false
      fi
    done <<< "${all_hosts}"
  done

  log_divider
  if [ "${all_checks_passed}" = true ]; then
    log_print "OK" "All SSH verifications completed successfully."
  else
    log_print "ERROR" "One or more SSH verification checks failed."
  fi
  log_divider
}

# Function: Check if user wants to verify SSH connections
ssh_verification_handler() {
  log_print "INPUT" "Do you want to verify SSH connections? (y/n): "
  read -r answer
  
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    ssh_connection_verifier
  else
    log_print "INFO" "Skipping SSH verification."
  fi
}

# Function: Prepend the Include directive to ~/.ssh/config for the k8s cluster
ssh_config_bootstrapper() {
  # Default to ~/.ssh/config if not set, though it should be set by the caller.
  local k8s_config_path="$1"
  if [[ -z "${k8s_config_path}" ]]; then
    log_print "ERROR" "No config path provided to ssh_config_bootstrapper."
    return 1
  fi

  local ssh_config_file="${SSH_CONFIG:-$HOME/.ssh/config}"
  local include_line="Include ${k8s_config_path}"

  # Ensure the directory exists and config file exists
  mkdir -p "$(dirname "${ssh_config_file}")" || {
    log_print "ERROR" "Failed to create directory $(dirname "${ssh_config_file}")"
    return 1
  }

  touch "${ssh_config_file}" || {
    log_print "ERROR" "Cannot touch ${ssh_config_file}"
    return 1
  }
  chmod 600 "${ssh_config_file}"

  # Check if the Include line already exists in the file.
  if grep -Fxq "${include_line}" "${ssh_config_file}"; then
    log_print "OK" "'${include_line}' already exists in ${ssh_config_file}."
    return 0
  fi

  log_print "TASK" "Prepending '${include_line}' to ${ssh_config_file}..."

  # Create a temporary file to safely build the new config
  local temp_file
  temp_file=$(mktemp) || {
    log_print "ERROR" "Failed to create temporary file."
    return 1
  }

  # Write the new Include line to the temporary file first.
  echo "${include_line}" > "${temp_file}" || {
    log_print "ERROR" "Failed to write to temporary file."
    rm "${temp_file}"
    return 1
  }

  # Append the content of the original config file to the temporary file.
  cat "${ssh_config_file}" >> "${temp_file}" || {
    log_print "ERROR" "Failed to read from ${ssh_config_file}."
    rm "${temp_file}"
    return 1
  }

  # Atomically replace the old config with the new one.
  mv "${temp_file}" "${ssh_config_file}" || {
    log_print "ERROR" "Failed to replace ${ssh_config_file} with the updated version."
    rm "${temp_file}"
    return 1
  }

  # Re-apply strict permissions in case mv changed them
  chmod 600 "${ssh_config_file}"
  log_print "OK" "SSH config updated."
}

# Function: Remove the Include directive from ~/.ssh/config for the k8s cluster
ssh_config_include_unbootstrapper() {
  local k8s_config_path="$1"
  if [[ -z "${k8s_config_path}" ]]; then
    log_print "ERROR" "No config path provided to ssh_config_include_unbootstrapper."
    return 1
  fi
  
  local ssh_config_file="${SSH_CONFIG:-$HOME/.ssh/config}"
  if [[ -z "${SSH_CONFIG}" ]]; then
    log_print "ERROR" "SSH_CONFIG is not defined"
    exit 1
  fi
  
  local include_line="Include ${k8s_config_path}"
  if [[ -f "${ssh_config_file}" ]]; then
    sed -i "\|${include_line}|d" "${ssh_config_file}"
  else
    log_print "WARN" "${ssh_config_file} does not exist, skipping removal"
  fi
}

known_hosts_bootstrapper() {
  if [ $# -lt 2 ]; then
    log_print "ERROR" "Not enough arguments. Usage: known_hosts_bootstrapper <config_name> [skip_poll] <host1> [<host2>...]"
    return 1
  fi

  local config_name="$1"
  shift # Shift arguments to the left, $1 is gone.
  local perform_poll=true

  # Check if the new first argument is our flag.
  if [[ "$1" == "skip_poll" ]]; then
    perform_poll=false
    shift # Shift again, flag is gone, remaining arguments are hosts.
  fi

  # After potential shifts, if no arguments remain, there are no hosts to process.
  if [ $# -eq 0 ]; then
    log_print "ERROR" "No hosts provided to known_hosts_bootstrapper."
    return 1
  fi

  local known_hosts_file="$HOME/.ssh/known_hosts_${config_name}"
  
  log_print "STEP" "Preparing SSH known_hosts: ${known_hosts_file}"
  mkdir -p "$HOME/.ssh"
  rm -f "${known_hosts_file}"
  
  log_print "TASK" "Scanning host keys for all nodes..."

  local tmp_dir
  tmp_dir=$(mktemp -d) || { log_print "ERROR" "Failed to create temp dir"; return 1; }

  local pids=()

  scan_single_host() {
    local target_host="$1"
    local output_file="$2"
    
    if ${perform_poll}; then
      log_print "TASK" "Waiting for SSH on ${target_host} ..."
      for ((attempt=1; attempt<=150; attempt++)); do
        local keys_found
        keys_found=$(ssh-keyscan -t ed25519 -T 2 -H "${target_host}" 2>/dev/null || true)
        if [[ -n "${keys_found}" ]] && [[ "${keys_found}" == *"ssh-ed25519"* ]]; then
          echo "${keys_found}" > "${output_file}"
          log_print "OK" "${target_host} is ready."
          return 0
        fi
        sleep 1
      done
      log_print "ERROR" "Timed out waiting for ${target_host}"
      return 1
    else
      if ssh-keyscan -T 5 -H "${target_host}" > "${output_file}" 2>/dev/null; then
					log_print "OK" "Scanned ${target_host}"
					return 0
      else
					log_print "WARN" "Failed to scan ${target_host}"
					return 1
      fi
    fi
  }

  for host in "$@"; do
    ( scan_single_host "${host}" "${tmp_dir}/${host}.txt" ) &
    pids+=($!)
  done

  local failed_count=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      ((failed_count++))
    fi
  done

  cat "${tmp_dir}"/*.txt >> "${known_hosts_file}" 2>/dev/null
  rm -rf "${tmp_dir}"

  if [ $failed_count -gt 0 ]; then
    log_print "ERROR" "${failed_count} hosts failed to initialize SSH."
    return 1
  fi

  log_print "OK" "Host key scanning complete."
  log_divider
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -eq 0 ]]; then
    log_print "ERROR" "No function specified"
    exit 1
  fi
  "$@"
fi
