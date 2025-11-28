#!/bin/bash

# This script contains functions for managing the Packer image build process.

# Function: Clean up Packer output directory and related artifacts
packer_artifact_cleaner() {
  echo ">>> STEP: Cleaning Packer artifacts..."

  local target_layer="$1"
  if [ -z "$target_layer" ]; then
    echo "FATAL: No Packer layer specified for packer_artifact_cleaner function." >&2
    return 1
  fi

  local layers_to_clean=()

  if [[ "$target_layer" == "all" ]]; then
    echo "#### Preparing to clean all Packer output directories..."
    if [ ${#ALL_PACKER_BASES[@]} -eq 0 ]; then
      echo "Warning: ALL_PACKER_BASES array is not defined. Cannot clean 'all'."
    else
      layers_to_clean=("${ALL_PACKER_BASES[@]}")
    fi
  else
    layers_to_clean=("$target_layer")
  fi

  for base_name in "${layers_to_clean[@]}"; do
    echo "#### Cleaning output for layer: ${base_name}"
    rm -rf "${PACKER_DIR}/output/${base_name}"
  done

  # --- Generic Packer Cache Cleanup ---
  if [ -d ~/.cache/packer ]; then
    echo "#### Cleaning Packer cache on host (preserving ISOs)..."
    # Use 'sudo' to ensure we can remove any stale lock files created by
    # previous runs, regardless of ownership or permissions.
    find ~/.cache/packer -mindepth 1 ! -name '*.iso' -print0 | sudo xargs -0 rm -rf
  fi

  echo "#### Packer artifact cleanup completed."
  echo "--------------------------------------------------"
}

# Function: Execute Packer build
# The base_name now corresponds to the *.pkrvars.hcl file to use.
packer_build_executor() {
  local base_name="$1"
  if [ -z "$base_name" ]; then
    echo "FATAL: No Packer build type specified for packer_build_executor function." >&2
    return 1
  fi

  # Construct the path to the specific var file.
  local build_var_file="${PACKER_DIR}/${base_name}.pkrvars.hcl"

  if [ ! -f "$build_var_file" ]; then
    echo "FATAL: Packer var file not found: ${build_var_file}" >&2
    return 1
  fi

  echo ">>> STEP: Starting new Packer build for [${base_name}]..."

	local override_args=""

	if [[ -n "${PKR_VAR_NET_BRIDGE+x}" ]]; then
		override_args+=" -var net_bridge=${PKR_VAR_NET_BRIDGE}"
	fi

	if [[ -n "${PKR_VAR_NET_DEVICE+x}" ]]; then
		override_args+=" -var net_device=${PKR_VAR_NET_DEVICE}"
	fi

  # The command now loads the common values file first, then the specific
  # build var file, and runs from the root Packer directory.
  local cmd="packer init . && packer build \
    -var-file=values.pkrvars.hcl \
    -var-file=${base_name}.pkrvars.hcl \
		${override_args} \
    ."

  # Add this to abort and debug if packer build failed.
  # -on-error=abort \

  run_command "${cmd}" "${PACKER_DIR}"

  echo "#### Packer build complete. New base image for [${base_name}] is ready."
  echo "--------------------------------------------------"
}

# Function: Display a sub-menu to select and run a Packer build.
packer_menu_handler() {
  local packer_build_executor_options=("Build ALL Packer Images" "${ALL_PACKER_BASES[@]}" "Back to Main Menu")

  echo
  PS3=">>> Select a Packer build to run: "
  select build_base in "${packer_build_executor_options[@]}"; do
    if [[ "$build_base" == "Back to Main Menu" ]]; then
      echo "# Returning to main menu..."
      break

    elif [[ "$build_base" == "Build ALL Packer Images" ]]; then
      echo "# Executing Batch Build for ALL Packer Images..."      
      if ! ssh_key_verifier; then break; fi
      libvirt_service_manager
      packer_artifact_cleaner "all"

      for base in "${ALL_PACKER_BASES[@]}"; do
        packer_build_executor "${base}"
      done

      execution_time_reporter
      break 2

    elif [[ " ${ALL_PACKER_BASES[*]} " == *"${build_base}"* ]]; then
      echo "# Executing Rebuild Packer workflow for [${build_base}]..."
      if ! ssh_key_verifier; then break; fi
      libvirt_service_manager
      packer_artifact_cleaner "${build_base}"
      packer_build_executor "${build_base}"
      execution_time_reporter
      break 2
    else
      echo "Invalid option $REPLY"
    fi
  done
}