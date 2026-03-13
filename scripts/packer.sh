#!/bin/bash

# This script contains functions for managing the Packer image build process.

# Function: Clean up Packer output directory and related artifacts
packer_artifact_cleaner() {
  log_print "STEP" "Cleaning Packer artifacts..."

  local target_layer="$1"
  if [ -z "$target_layer" ]; then
    log_print "FATAL" "No Packer layer specified for packer_artifact_cleaner function."
    return 1
  fi

  local layers_to_clean=()

  if [[ "$target_layer" == "all" ]]; then
    log_print "INFO" "Preparing to clean all Packer output directories..."
    if [ -z "$ALL_PACKER_BASES" ]; then
      log_print "WARN" "ALL_PACKER_BASES is empty. Cannot clean 'all'."
    else
      read -r -a layers_to_clean <<< "$ALL_PACKER_BASES"
    fi
  else
    layers_to_clean=("$target_layer")
  fi

  for base_name in "${layers_to_clean[@]}"; do
    log_print "TASK" "Cleaning output for layer: ${base_name}"
    # Dedicated output directory matches var-file name
    rm -rf "${PACKER_DIR}/output/${base_name}"
  done

  # Generic Packer Cache Cleanup
  if [ -d ~/.cache/packer ]; then
    log_print "TASK" "Cleaning Packer cache on host (preserving ISOs)..."
    # Use 'sudo' to ensure we can remove any stale lock files created by
    # previous runs, regardless of ownership or permissions.
    find ~/.cache/packer -mindepth 1 ! -name '*.iso' -print0 | sudo xargs -0 rm -rf
  fi

  log_print "OK" "Packer artifact cleanup completed."
  log_divider
}

# Function: Execute Packer build
# The base_name now corresponds to the *.pkrvars.hcl file to use.
packer_build_executor() {
  local base_name="$1"
  if [ -z "$base_name" ]; then
    log_print "FATAL" "No Packer build type specified for packer_build_executor function."
    return 1
  fi

  # Determine sub-directory based on file existence
  local sub_dir="10-services"
  if [ -f "${PACKER_DIR}/00-base-os/${base_name}.pkrvars.hcl" ]; then
    sub_dir="00-base-os"
  fi

  local target_packer_dir="${PACKER_DIR}/${sub_dir}"
  # Construct the path to the specific var file.
  local build_var_file="${target_packer_dir}/${base_name}.pkrvars.hcl"

  if [ ! -f "$build_var_file" ]; then
    log_print "FATAL" "Packer var file not found: ${build_var_file}"
    return 1
  fi

  log_print "STEP" "Starting new Packer build for [${base_name}] in [${sub_dir}]..."

	# Ensure we are using the Development Vault context for Packer builds
	vault_context_handler "dev"

	local override_args=""

	if [[ -n "${PKR_VAR_NET_BRIDGE+x}" ]]; then
		override_args+=" -var net_bridge=${PKR_VAR_NET_BRIDGE}"
	fi

	if [[ -n "${PKR_VAR_NET_DEVICE+x}" ]]; then
		override_args+=" -var net_device=${PKR_VAR_NET_DEVICE}"
	fi

  # The command now loads the common values file from one level up,
  # then the specific build var file, and runs from the target sub-directory.
  local cmd="packer init . && packer build \
    -var-file=../values.pkrvars.hcl \
    -var-file=${base_name}.pkrvars.hcl \
    -var \"build_name=${base_name}\" \
		${override_args} \
    ."

  run_command "${cmd}" "${target_packer_dir}"

  # --- DEDUPLICATION: Post-build Operations ---
  # Generate checksum for the artifact (moved from HCL post-processor to shell script)
  local output_dir="${PACKER_DIR}/output/${base_name}"
  
  # Discover the .qcow2 file in the output directory (assuming one per build)
  local image_file=$(find "${output_dir}" -maxdepth 1 -name "*.qcow2" -printf "%f\n" | head -n 1)
  
  if [ -n "$image_file" ]; then
    log_print "TASK" "Generating SHA256 checksum for ${image_file}..."
    pushd "${output_dir}" > /dev/null
    sha256sum "${image_file}" > "${image_file}.sha256"
    popd > /dev/null
    log_print "INFO" "Checksum generated at output/${base_name}/${image_file}.sha256"
  fi

  log_print "OK" "Packer build complete. New image for [${base_name}] is ready."
  log_divider
}

# Function: Internal helper for selecting and building images in a specific layer
# Arguments: $1 = layer subdirectory, $2 = Title for the menu
packer_layer_selector() {
	local sub_dir_name="$1"
	local menu_title="$2"
	local layer_path="${PACKER_DIR}/${sub_dir_name}"

	local layers=($(find "${layer_path}" -name "*.pkrvars.hcl" -printf '%f\n' | sed 's/\.pkrvars\.hcl//g' | sort))
	local options=("${layers[@]}" "Build ALL in ${menu_title}" "Back")

	PS3=$'\n\033[1;34m[INPUT] Select ${menu_title}: \033[0m'
	select img in "${options[@]}"; do
		if [[ "$img" == "Back" ]]; then
			return 0
		elif [[ "$img" == "Build ALL in ${menu_title}" ]]; then
			log_print "STEP" "Executing Batch Build for ALL ${menu_title}..."
			if [[ "$sub_dir_name" == "00-base-os" ]]; then
				packer_artifact_cleaner "all"
			fi
			for b in "${layers[@]}"; do
				packer_artifact_cleaner "$b"
				packer_build_executor "$b"
			done
			return 1 # Break from parent loop as well
		elif [[ -n "$img" ]]; then
			packer_artifact_cleaner "$img"
			packer_build_executor "$img"
			return 1 # Break from parent loop
		fi
	done
}

# Function: Display a sub-menu to select and run a Packer build.
packer_menu_handler() {
  while true; do
		echo
		log_print "INFO" "Select Packer category to build:"
		log_divider
		local main_options=("Base OS Layers" "Service Layers" "Build ALL" "Back to Main Menu")
		PS3=$'\n\033[1;34m[INPUT] Select a category: \033[0m'

		select category in "${main_options[@]}"; do
			case $category in
				"Base OS Layers")
					if ! packer_layer_selector "00-base-os" "Base OS Images"; then break 2; fi
					break
					;;
				"Service Layers")
					if ! packer_layer_selector "10-services" "Service Images"; then break 2; fi
					break
					;;
				"Build ALL")
					log_print "STEP" "Executing FULL Batch Build (Base -> Services)..."
					packer_artifact_cleaner "all"
					
					# 1. Build Base Layers
					local base_layers=($(find "${PACKER_DIR}/00-base-os" -name "*.pkrvars.hcl" -printf '%f\n' | sed 's/\.pkrvars\.hcl//g' | sort))
					for b in "${base_layers[@]}"; do
						packer_build_executor "$b"
					done
					
					# 2. Build Service Layers
					local service_layers=($(find "${PACKER_DIR}/10-services" -name "*.pkrvars.hcl" -printf '%f\n' | sed 's/\.pkrvars\.hcl//g' | sort))
					for s in "${service_layers[@]}"; do
						packer_build_executor "$s"
					done
					break 2
					;;
				"Back to Main Menu")
					return
					;;
				*) log_print "ERROR" "Invalid option $REPLY" ;;
			esac
		done
	done
  execution_time_reporter
}
