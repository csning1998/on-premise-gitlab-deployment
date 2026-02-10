#!/bin/bash

### This script contains general utility and helper functions.

# Prevent multiple loading
if [[ -n "${UTILS_SH_LOADED:-}" ]]; then
	# Prevent multiple loading in subshell (e.g. CI/CD pipeline, polluted env)
  (return 0 2>/dev/null) && return 0 || exit 0
fi
readonly UTILS_SH_LOADED=true

# ANSI Color Codes
readonly CLR_RESET='\033[0m'
readonly CLR_RED='\033[0;31m'
readonly CLR_GREEN='\033[0;32m'
readonly CLR_YELLOW='\033[0;33m'
readonly CLR_CYAN='\033[0;36m'
readonly CLR_PURPLE='\033[0;35m'
readonly CLR_BOLD_RED='\033[1;31m'
readonly CLR_BOLD_BLUE='\033[1;34m'

# Function: Unified Logging Interface
log_print() {
  local level="${1:-INFO}"
  local msg="${2:-}"

  case "${level^^}" in
    "STEP")    echo -e "${CLR_BOLD_BLUE}[STEP] ${msg}${CLR_RESET}" ;;
    "INFO")    echo -e "${CLR_GREEN}[INFO] ${msg}${CLR_RESET}" ;;
    "TASK")    echo -e "${CLR_CYAN}[TASK] ${msg}${CLR_RESET}" ;;
    "WARN")    echo -e "${CLR_YELLOW}[WARN] ${msg}${CLR_RESET}" ;;
    "ERROR")   echo -e "${CLR_RED}[ERROR] ${msg}${CLR_RESET}" >&2 ;;
    "FATAL")   echo -e "${CLR_BOLD_RED}[FATAL] ${msg}${CLR_RESET}" >&2 ;;
    "OK"|"SUCCESS") echo -e "${CLR_GREEN}[OK] ${msg}${CLR_RESET}" ;;
    "INPUT")   echo -e "${CLR_PURPLE}[INPUT] ${msg}${CLR_RESET}" ;;
    *)         echo -e "${CLR_RESET}[LOG] ${msg}${CLR_RESET}" ;;
  esac
}

# Function: Print a visual divider
log_divider() {
  local char="${1:--}"
  local length="${2:-60}"
  local color="${3:-${CLR_RESET}}"
  
  local line
  # Generate a line of 'length' spaces, then replace spaces with 'char'
  printf -v line "%*s" "$length" ""
  echo -e "${color}${line// /$char}${CLR_RESET}"
}

# Function: Execute a command string based on the selected strategy.
run_command() {
  local cmd_string="$1"
	local host_work_dir="${2:-${SCRIPT_DIR}}" # Optional working directory for native mode

  if [[ "${ENVIRONMENT_STRATEGY}" == "container" ]]; then

    # Containerized Execution Path
    local compose_cmd="podman compose"
    local compose_file="compose.yml"
    local service_name="iac-runner"
    local container_name="iac-runner"
    local engine_cmd="podman"

		# 0. Determine the Container AND Service to use
    local container_work_dir="${host_work_dir}"

    # 1. Check if Podman is installed
    if ! command -v podman >/dev/null 2>&1; then
			log_print "FATAL" "Container engine command 'podman' not found. Please install it to proceed."
      exit 1
    fi

    # 2. Check if the required engine is installed
    if ! command -v "${engine_cmd##* }" >/dev/null 2>&1; then
			log_print "FATAL" "Container engine command '${engine_cmd##* }' not found. Please install it to proceed."
      exit 1
    fi

    # 3. Ensure the controller service is running.
    if ! ${engine_cmd} ps -q --filter "name=${container_name}" | grep -q .; then
			log_print "TASK" "Starting container service '${container_name}'..."
      (cd "${SCRIPT_DIR}" && ${compose_cmd} -f "${compose_file}" up -d "${service_name}")
    fi

    # 4. Execute the command within the container.
    # The working directory inside the container is always /app.
    # Map the host path to the container's /app path.

    # local container_work_dir="${host_work_dir/#$SCRIPT_DIR//app}"
    echo "INFO: Executing command in container '${container_name}'..."

		${engine_cmd} exec \
      -e "VAULT_ADDR=${DEV_VAULT_ADDR}" \
      -e "VAULT_CACERT=${DEV_VAULT_CACERT}" \
      -e "VAULT_TOKEN=${DEV_VAULT_TOKEN}" \
      -w "${container_work_dir}" \
      "${container_name}" \
      bash -c "${cmd_string}"

  else
    # Native Mode: Execute the command directly on the host. 
    (cd "${host_work_dir}" && eval "${cmd_string}")
  fi
}

check_and_fix_permissions() {
  # --- 1. Identify User and Project Root Directory ---
  local current_user

  current_user=$(whoami)

  # --- 2. Define Directories for Permission Check ---
  local directories_to_check=(
    "${SCRIPT_DIR}"
    "${HOME}/.cache/packer"
    "${HOME}/.ssh"
  )

  log_print "INFO" "Checking directory ownership for user '${current_user}'."
  
  local needs_fix=false
  local return_code=0

  # --- 3. Iterate, Check, and Correct Ownership ---
  for dir in "${directories_to_check[@]}"; do
    if [ ! -d "${dir}" ]; then
      log_print "INFO" "Skipping non-existent directory: ${dir}"
      continue
    fi

    # Efficiently find the first file/directory not owned by the current user.
    local incorrect_owner_path
    incorrect_owner_path=$(find "${dir}" -not -user "${current_user}" -print -quit)

    if [ -n "${incorrect_owner_path}" ]; then
      needs_fix=true
      log_print "WARN" "Incorrect ownership detected in '${dir}'."
      log_print "WARN" "      Example path with incorrect owner: ${incorrect_owner_path}"
      
      # Attempt to fix ownership.
      local fix_cmd="sudo chown -R ${current_user}:${current_user} ${dir}"
      log_print "TASK" "Executing: ${fix_cmd}"
      
      if eval "${fix_cmd}"; then
        log_print "OK" "Successfully corrected ownership for '${dir}'."
      else
        log_print "FATAL" "Failed to correct ownership for '${dir}'. Please check sudo permissions."
        return_code=1 # Mark that a failure occurred
      fi
    else
      log_print "INFO" "Ownership verified for '${dir}'."
    fi
  done

  # --- 4. Final Status Report ---
  if ! ${needs_fix}; then
    log_print "OK" "All checked directories have correct ownership."
  else
    if [ "${return_code}" -eq 0 ]; then
      log_print "OK" "Permission check and correction process completed successfully."
    else
      log_print "ERROR" "The permission fix process encountered one or more errors."
    fi
  fi

  return ${return_code}
}

# Function: Report execution time
execution_time_reporter() {
  local END_TIME DURATION MINUTES SECONDS
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  MINUTES=$((DURATION / 60))
  SECONDS=$((DURATION % 60))
	
	log_divider
	log_print "INFO" "Execution time: ${MINUTES}m ${SECONDS}s"
	log_divider
}

# Function: Prompts for strict manual confirmation before destructive actions
manual_confirmation_prompter() {
  local target_desc="${1:-resources}"

	log_divider "!"
	log_print "WARN" "WARNING: You are about to DESTROY ALL ${target_desc}."
	log_print "WARN" "This action is IRREVERSIBLE and will wipe the selected environment data."
	log_divider "!"
  
  log_print "INPUT" "Type 'Y' or 'y' to confirm execution: "
	read -r confirmation
  
	if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
		log_print "INFO" "Operation aborted by user."
    return 1
  fi
  return 0
}
